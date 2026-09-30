"""Natural-number IDs: boundary unit cases and compact real-CLI regressions."""
import copy
import sys
import tempfile
import unittest
from test_task_queue import Repo, AUTH, SOURCE


class TaskNumbering(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(prefix='numbering-test-')
        self.addCleanup(self.tmp.cleanup)
        self.r = Repo(self.tmp.name)

    def model(self):
        if str(SOURCE / 'tool') not in sys.path:
            sys.path.insert(0, str(SOURCE / 'tool'))
        import queue_model
        return queue_model

    def test_01_first_number_and_actual_paths_are_not_padded(self):
        result = self.r.create(); self.assertEqual(result['task'], 'T1')
        self.assertEqual(result['files']['tasks'][0]['task'], 'queue/tasks/T1/task.md')
        self.assertTrue((self.r.root / 'queue/tasks/T1/goal.md').is_file())
        self.assertFalse((self.r.root / 'queue/tasks/T0001').exists())
        self.assertEqual(self.r.events()[-1]['numbering_version'], 2)

    def test_02_decimal_boundaries_do_not_need_large_cli_loops(self):
        m = self.model()
        for maximum, expected in [(0,'T1'),(9,'T10'),(99,'T100'),(999,'T1000'),(9999,'T10000')]:
            for previous in ([f'T{maximum}'], [f'T{maximum:04d}']) if maximum else [[],[]]:
                with self.subTest(previous=previous):
                    self.assertEqual(m.next_task_id(dict.fromkeys(previous), numbering_version=2), expected)
        self.assertEqual(m.next_task_id({'T0009': {}}, numbering_version=1), 'T0010')

    def test_03_new_validation_is_strict_and_legacy_validation_is_unchanged(self):
        m = self.model()
        self.assertEqual(m.task_id('T1', numbering_version=2),'T1')
        self.assertEqual(m.task_id('T10000', numbering_version=2),'T10000')
        self.assertEqual(m.task_id('T0001'),'T0001')
        for value in ['T0','T01','T0001','T0000','T-1','T+1','t1','T１','T1x']:
            with self.subTest(value=value), self.assertRaises(m.QueueError):
                m.task_id(value, numbering_version=2)
        with self.assertRaises(m.QueueError): m.task_id('T1')

    def test_04_same_numeric_identity_cannot_exist_in_two_spellings(self):
        m = self.model()
        with self.assertRaises(m.QueueError):
            m.next_task_id({'T0001': {}, 'T1': {}}, numbering_version=2)

    def test_05_status_window_and_packet_task_order_are_numeric(self):
        ids = [self.r.create(approve=False)['task'] for _ in range(12)]
        self.assertEqual(ids,[f'T{i}' for i in range(1,13)])
        for ident in ['T1','T2','T10']: self.r.write('approve',ident,*AUTH)
        state = self.r.call('status')
        self.assertEqual([t['id'] for t in state['tasks']],ids)
        self.assertEqual(state['window']['occupied'],['T1','T2','T10'])
        pack = self.r.call('state','get')
        order = list(dict.fromkeys(row['source'].split('/')[2] for row in pack['files'] if row['source'].startswith('queue/tasks/')))
        self.assertEqual(order,['T1','T2','T10'])
        self.r.call('state','check','--context',pack['context'])

    def test_06_cancel_does_not_reuse_and_retry_keeps_original_number(self):
        first = self.r.create(request='same-number');self.r.write('cancel',first['task'],*AUTH)
        retried = self.r.create(request='same-number')
        self.assertTrue(retried['already_applied']);self.assertEqual(retried['task'],'T1')
        self.assertEqual(self.r.create()['task'],'T2')
        self.assertTrue((self.r.root/'.shell/queue/archive/T1/task.md').is_file())

    def test_07_existing_padded_ids_keep_address_and_are_not_aliases(self):
        import test_task_queue
        old, files, prefix = test_task_queue.QueueIntegration.legacy_v1(self, terminal=False)
        self.assertEqual(old,'T0001')
        new = self.r.create()['task']; self.assertEqual(new,'T2')
        self.assertTrue(self.r.raw().startswith(prefix))
        self.assertEqual((self.r.root/f'queue/tasks/{old}/approval-001.md').read_bytes(),files['approval-001.md'])
        self.assertEqual(self.r.call('status','T1',expected=1)['code'],'identity')
        child = self.r.create(approve=False,deps=[old,new])['task']
        self.assertEqual((child,self.r.status(child)['deps']),('T3',[old,new]))
        self.assertEqual(self.r.commit().returncode,0)

    def test_08_marker_cannot_be_unknown_or_downgraded(self):
        m=self.model();events=self.r.events()
        for value in [0,3,True,'2']:
            broken=copy.deepcopy(events);broken[0]['numbering_version']=value
            with self.subTest(value=value),self.assertRaises(m.QueueError):m.replay(broken)
        self.r.create();events=self.r.events();events[-1].pop('numbering_version')
        with self.assertRaises(m.QueueError):m.replay(events)

    def test_09_forged_padded_creation_is_rejected_in_new_event(self):
        m=self.model();self.r.create();events=self.r.events();events[-1]['data']['id']='T0001'
        with self.assertRaises(m.QueueError):m.replay(events)

    def test_10_natural_parent_dependency_and_lifecycle_work(self):
        dep=self.r.create()['task'];self.r.write('claim',dep);self.r.deliver(dep);self.r.write('close',dep,*AUTH)
        parent=self.r.create(approve=False,deps=[dep])['task']
        child=self.r.create(approve=False,parent=parent)['task']
        self.assertEqual((dep,parent,child),('T1','T2','T3'))
        self.r.write('approve',parent,*AUTH);self.r.write('approve',child,*AUTH)
        self.r.write('claim',child);self.r.write('release',child,'--text','交接保持自然编号')
        self.r.write('claim',child);self.r.deliver(child);self.r.write('close',child,*AUTH)
        self.r.write('claim',parent);self.r.deliver(parent);self.r.write('close',parent,*AUTH)
        self.assertEqual(self.r.status(parent)['status'],'通过')
        self.assertEqual(self.r.commit().returncode,0)

if __name__=='__main__':unittest.main()
