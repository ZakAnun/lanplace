import localUnitTest from './LocalUnit.test';
import bleAdvertParserTest from './BleAdvertParser.test';
import radarLayoutHelperTest from './RadarLayoutHelper.test';
import radarDeviceLayoutTest from './RadarDeviceLayout.test';
import deviceEnvironmentTest from './DeviceEnvironment.test';
import radarOrbitGeometryTest from './RadarOrbitGeometry.test';
import devicePickerSheetLayoutTest from './DevicePickerSheetLayout.test';

export default function testsuite() {
  localUnitTest();
  bleAdvertParserTest();
  radarLayoutHelperTest();
  radarDeviceLayoutTest();
  radarOrbitGeometryTest();
  devicePickerSheetLayoutTest();
  deviceEnvironmentTest();
}