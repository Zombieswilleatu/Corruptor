#!/usr/bin/env python3
"""One V26 decision using only an observation and native admission replies."""
import sys

from u13_pysim.codec import dumps, loads
from u13_doctrine.common import CommonSmartCore

PROTOCOL = 'U13_COMMON_BOT_PIPE_V1'


def send(value, output):
    output.write(dumps(value) + '\n')
    output.flush()


def receive(source):
    line = source.readline()
    if not line:
        raise ValueError('native admission pipe closed')
    return loads(line)


def serve(source, output):
    request = receive(source)
    if request.get('protocol') != PROTOCOL:
        raise ValueError('bot protocol mismatch')
    view, mode = request['view'], request['mode']
    policy = CommonSmartCore()
    calls = 0

    def preview(plan):
        nonlocal calls
        calls += 1
        if calls > policy.limits.previews:
            raise ValueError('native preview budget exceeded')
        send(dict(action='preview', index=calls, plan=plan), output)
        reply = receive(source)
        if reply.get('action') != 'preview_result' or reply.get('index') != calls:
            raise ValueError('native preview sequence mismatch')
        if reply['result'].get('action') not in ('legal', 'invalid'):
            raise ValueError('invalid native admission result')
        return reply['result']

    if mode == 'plan':
        decision = policy.decide(view, preview)
    elif mode in ('stockpile', 'slaver'):
        decision = policy.choose_card(view, mode)
    else:
        raise ValueError('unknown bot decision mode')
    send(dict(action='decision', protocol=PROTOCOL, policy=policy.policy_id,
              previews=calls, decision=decision), output)


def main():
    # Explicit UTF-8 works in Windows terminals and redirected Godot pipes.
    sys.stdin.reconfigure(encoding='utf-8')
    sys.stdout.reconfigure(encoding='utf-8')
    if sys.argv[1:] == ['--check']:
        print(CommonSmartCore().policy_id)
        return
    try:
        serve(sys.stdin, sys.stdout)
    except Exception as error:
        send(dict(action='invalid', reason='common_bot_worker_failed', detail=str(error)), sys.stdout)
        raise SystemExit(1)


if __name__ == '__main__':
    main()
