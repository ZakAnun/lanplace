import agcAuditLayoutTest from '../../../test/AgcAuditLayout.test';
import radarLayoutHelperTest from '../../../test/RadarLayoutHelper.test';
import agcAuditFlowTest from './AgcAuditFlow.test';

export default function testsuite() {
  agcAuditLayoutTest();
  radarLayoutHelperTest();
  agcAuditFlowTest();
}
