import agcAuditLayoutTest from '../../../test/AgcAuditLayout.test';
import radarLayoutHelperTest from '../../../test/RadarLayoutHelper.test';
import radarDeviceLayoutTest from '../../../test/RadarDeviceLayout.test';
import sphereCameraMathTest from '../../../test/SphereCameraMath.test';
import inventoryDeviceMergeTest from '../../../test/InventoryDeviceMerge.test';
import permissionPurposeTest from '../../../test/PermissionPurpose.test';
import scanUiLabelsTest from '../../../test/ScanUiLabels.test';
import agcAuditFlowTest from './AgcAuditFlow.test';

export default function testsuite() {
  agcAuditLayoutTest();
  radarLayoutHelperTest();
  radarDeviceLayoutTest();
  sphereCameraMathTest();
  inventoryDeviceMergeTest();
  permissionPurposeTest();
  scanUiLabelsTest();
  agcAuditFlowTest();
}
