"""Exercise the real commit loop against a local Git remote, without cloud writes."""

# Standard-library helpers keep tests runnable on GitHub's hosted runners.
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import time
import unittest

ROOT = Path(__file__).resolve().parents[1]
GIT = shutil.which('git')


def run(*args, **kwargs):
    """Capture subprocess output, including diagnostics on assertion failures."""
    return subprocess.run(args, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                          universal_newlines=True, check=True, **kwargs)


class CommitCycleTests(unittest.TestCase):
    """Use real Git commits and inject transport failures and accelerated timers."""

    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.path = Path(self.temp.name)
        self.bin = self.path / 'bin'
        self.bin.mkdir()
        self.remote = self.path / 'remote.git'
        run(GIT, 'init', '--bare', str(self.remote))
        seed = self.path / 'seed'
        run(GIT, 'init', str(seed))
        run(GIT, '-C', str(seed), 'checkout', '-b', 'main')
        run(GIT, '-C', str(seed), '-c', 'user.name=Test', '-c',
            'user.email=test@example.invalid', 'commit', '--allow-empty', '-m', 'seed')
        run(GIT, '-C', str(seed), 'push', str(self.remote), 'main')
        self.key = self.path / 'key'
        run('ssh-keygen', '-q', '-t', 'ed25519', '-N', '', '-f', str(self.key))
        self.env = dict(os.environ, PATH=str(self.bin) + ':' + os.environ['PATH'],
                        REAL_GIT=GIT, TEST_DIR=str(self.path), TEST_REMOTE=str(self.remote),
                        GIT_EMAIL='test@example.invalid', GIT_USER='Test User',
                        GITHUB_REPO='example/renamed-repository', GIT_KEY_FILE=str(self.key),
                        GIT_KNOWN_HOSTS=str(ROOT / 'github_known_hosts'),
                        COMMIT_DELAY_MIN='1', COMMIT_DELAY_MAX='1', RETRY_DELAY='2',
                        REDEPLOY_WAIT='3', TEST_SUCCESSES='1')
        self.wrapper('git', '''case "$1" in
    clone)
        if [ -f "$TEST_DIR/fail-clone" ]; then
            rm "$TEST_DIR/fail-clone"
            exit 128
        fi
        for destination; do :; done
        exec "$REAL_GIT" clone --branch main "$TEST_REMOTE" "$destination" ;;
    push)
        if [ -f "$TEST_DIR/fail-push" ]; then
            rm "$TEST_DIR/fail-push"
            exit 1
        fi ;;
esac
exec "$REAL_GIT" "$@"
''')
        self.wrapper('shuf', 'echo 1\n')
        self.wrapper('date', '''if [ "$*" = '-u +%u' ]; then echo 1; else /bin/date "$@"; fi
''')
        self.wrapper('sleep', '''if [ "$1" = 3 ]; then
    count=$("$REAL_GIT" --git-dir="$TEST_REMOTE" rev-list --count main)
    if [ "$count" -gt "$TEST_SUCCESSES" ]; then
        touch "$TEST_DIR/finished"
        exec /bin/sleep 60
    fi
fi
''')

    def wrapper(self, name, body):
        """Place a controllable executable before the real tools on PATH."""
        path = self.bin / name
        path.write_text('#!/bin/sh\nset -eu\n' + body)
        path.chmod(0o755)

    def exercise(self, expected=1):
        """Wait for successful pushes, then terminate the production loop cleanly."""
        self.env['TEST_SUCCESSES'] = str(expected)
        log = tempfile.TemporaryFile(mode='w+')
        self.addCleanup(log.close)
        process = subprocess.Popen(['sh', str(ROOT / 'commit.sh')], env=self.env,
                                   stdout=log, stderr=log, start_new_session=True)
        try:
            deadline = time.monotonic() + 15
            while time.monotonic() < deadline:
                if (self.path / 'finished').exists() or process.poll() is not None:
                    break
                time.sleep(0.05)
            log.seek(0)
            output = log.read()
            self.assertTrue((self.path / 'finished').exists(), output)
            process.terminate()
            self.assertEqual(process.wait(timeout=3), 0)
        finally:
            # Also reap the test's synthetic long sleep.
            import signal
            try:
                os.killpg(process.pid, signal.SIGKILL)
            except ProcessLookupError:
                pass
            process.wait()
        count = run(GIT, '--git-dir=' + str(self.remote), 'rev-list', '--count', 'main')
        self.assertEqual(int(count.stdout), expected + 1)
        return output

    def test_pushes_to_named_branch_in_arbitrarily_named_repository(self):
        self.exercise()

    def test_recovers_from_clone_failure(self):
        (self.path / 'fail-clone').touch()
        self.assertIn('retrying in 2 seconds', self.exercise())

    def test_recovers_from_rejected_push_without_duplicate_commit(self):
        (self.path / 'fail-push').touch()
        self.assertIn('retrying in 2 seconds', self.exercise())

    def test_resumes_if_deployment_never_replaces_the_pod(self):
        self.assertIn('resuming the commit schedule', self.exercise(expected=2))

    def test_invalid_configuration_fails_before_waiting(self):
        self.env['COMMIT_DELAY_MIN'] = '0'
        result = subprocess.run(['sh', str(ROOT / 'commit.sh')], env=self.env,
                                stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(run(GIT, '--git-dir=' + str(self.remote), 'rev-list',
                             '--count', 'main').stdout.strip(), '1')


class DeploymentTests(unittest.TestCase):
    """Check credentials survive transport and failed kubectl steps stop deployment."""

    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.path = Path(self.temp.name)
        self.key = self.path / 'key'
        run('ssh-keygen', '-q', '-t', 'ed25519', '-N', '', '-f', str(self.key))
        self.env = dict(os.environ, PATH=str(self.path) + ':' + os.environ['PATH'],
                        TEST_DIR=str(self.path), IMAGE_URI='example.invalid/image:123',
                        GITHUB_REPOSITORY='example/repository', GIT_KEY=self.key.read_text().rstrip('\n'),
                        GIT_EMAIL='a@example.invalid', GIT_USER='Name "quoted": $HOME')
        kubectl = self.path / 'kubectl'
        kubectl.write_text('''#!/bin/sh
set -eu
printf '%s\\n' "$*" >> "$TEST_DIR/calls"
case "$1" in
    create)
        [ ! -f "$TEST_DIR/fail-create" ] || exit 1
        for argument; do
            case "$argument" in
                --from-file=key=*) cmp "${argument#--from-file=key=}" "$TEST_DIR/key" ;;
                --from-file=user=*) cp "${argument#--from-file=user=}" "$TEST_DIR/username" ;;
            esac
        done
        printf 'apiVersion: v1\\nkind: Secret\\n' ;;
    apply)
        for filename; do :; done
        if [ "$(basename "$filename")" = deployment.yml ]; then
            cp "$filename" "$TEST_DIR/rendered.yml"
        fi ;;
    rollout) [ ! -f "$TEST_DIR/fail-rollout" ] ;;
esac
''')
        kubectl.chmod(0o755)

    def deploy(self):
        return subprocess.run(['sh', str(ROOT / 'deploy.sh')], cwd=str(ROOT),
                              env=self.env, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                              universal_newlines=True)

    def test_preserves_multiline_key_and_special_characters(self):
        result = self.deploy()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual((self.path / 'username').read_text(), self.env['GIT_USER'])
        rendered = (self.path / 'rendered.yml').read_text()
        self.assertIn(self.env['IMAGE_URI'], rendered)
        self.assertIn(self.env['GITHUB_REPOSITORY'], rendered)
        self.assertNotIn('${', rendered)
        self.assertNotIn('PRIVATE KEY', rendered)
        self.assertIn('rollout status', (self.path / 'calls').read_text())

    def test_failed_secret_creation_prevents_apply(self):
        (self.path / 'fail-create').touch()
        self.assertNotEqual(self.deploy().returncode, 0)
        self.assertNotIn('apply', (self.path / 'calls').read_text())

    def test_failed_rollout_fails_deployment(self):
        (self.path / 'fail-rollout').touch()
        self.assertNotEqual(self.deploy().returncode, 0)
        self.assertIn('rollout status', (self.path / 'calls').read_text())


if __name__ == '__main__':
    unittest.main()
