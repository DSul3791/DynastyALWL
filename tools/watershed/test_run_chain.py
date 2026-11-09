"""Unit tests for run_chain.py (the chain runner that skips unchanged stages; docs/water/generation_cost_audit.md section 4): an
.npz is hashed by its arrays, each stage's code and params blocks, and a small stage in a temporary folder that runs once, is skipped,
and runs again when what it reads, its params block or its output changes (but not for a text note). They run one tiny Python
command, read no run files, need numpy only, and take a few seconds.

Run on David4 or Dave's PC, never in the cloud:
  python tools/watershed/test_run_chain.py        (or: python -m pytest tools/watershed/test_run_chain.py)
"""
import json
import os
import sys
import tempfile

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import run_chain as rc    # noqa: E402

STAGE_SCRIPT = '''import json, sys
P = json.load(open(sys.argv[3]))
value = float(open(sys.argv[1]).read()) * P['fake']['factor']
open(sys.argv[2] + '/out.txt', 'w').write(str(value))
'''


def test_npz_hashed_by_arrays():
    with tempfile.TemporaryDirectory() as d:
        a, b = np.arange(12.0).reshape(3, 4), np.ones(5, np.int16)
        np.savez(f'{d}/one.npz', a=a, b=b)
        np.savez_compressed(f'{d}/two.npz', b=b, a=a)
        np.savez_compressed(f'{d}/three.npz', a=a + 1.0, b=b)
        assert rc.file_sha(f'{d}/one.npz') == rc.file_sha(f'{d}/two.npz'), 'the same arrays, saved another way, hash the same'
        assert rc.file_sha(f'{d}/one.npz') != rc.file_sha(f'{d}/three.npz'), 'a changed array changes the hash'


def test_code_and_params_of_the_stages():
    names = lambda s: [os.path.basename(p) for p in rc.code_closure(s)]
    assert {'glacial.py', 'evolve.py', 'peaks.py', 'world.py', 'rock.py', 'lem.py'} <= set(names('glacial.py')), names('glacial.py')
    assert 'glacial.py' not in names('lakes.py') and 'network.py' not in names('record.py')
    assert {'glacial', 'evolve', 'world', 'peaks'} <= set(rc.param_blocks(rc.code_closure('glacial.py')))
    assert {'network', 'record', 'groundwater'} <= set(rc.param_blocks(rc.code_closure('network.py')))
    assert 'network' not in rc.param_blocks(rc.code_closure('lakes.py')), 'a network rule does not rerun the lakes'


def test_a_stage_skips_and_reruns():
    with tempfile.TemporaryDirectory() as d:
        script = os.path.join(d, 'fake_stage.py')
        open(script, 'w').write(STAGE_SCRIPT)
        params = os.path.join(d, 'params.json')
        P = {'_note': 'a', 'fake': {'_note': 'x', 'factor': 2.0}, 'other': {'k': 1}}
        json.dump(P, open(params, 'w'))
        src, out = os.path.join(d, 'in.txt'), os.path.join(d, 'out')
        open(src, 'w').write('21')
        stage = dict(name='fake', script=script, out=out, outputs=['out.txt'], reads=[src], cmd=[sys.executable, script, src, out, params])

        def why(P_now):
            json.dump(P_now, open(params, 'w'))
            return rc.decide(stage, P_now, params, d)[2]

        assert why(P) == 'no out.txt yet'
        proc, t0 = rc._start(stage)
        assert rc._finish(stage, proc, t0, d, P, params) and open(f'{out}/out.txt').read() == '42.0'
        assert why(P) is None, 'nothing changed: skipped'
        assert why(dict(P, other={'k': 2})) is None, 'a params block the stage does not read'
        assert why(dict(P, fake={'_note': 'changed', 'factor': 2.0})) is None, 'a text note'
        assert 'params fake' in why(dict(P, fake={'_note': 'x', 'factor': 3.0}))
        open(src, 'w').write('22')
        assert 'reads in.txt' in why(P)
        open(src, 'w').write('21')
        assert why(P) is None, 'the same content again: skipped'
        os.remove(f'{out}/out.txt')
        assert why(P) == 'no out.txt yet'
        stage_missing = dict(stage, reads=[os.path.join(d, 'nothing.txt')])
        assert rc.decide(stage_missing, P, params, d)[0] is None, 'a file it reads is not there'


if __name__ == '__main__':
    tests = [v for k, v in sorted(globals().items()) if k.startswith('test_') and callable(v)]
    for t in tests:
        t()
        print('ok', t.__name__)
    print(f'{len(tests)} tests passed')
