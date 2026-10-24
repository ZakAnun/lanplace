import localUnitTest from './LocalUnit.test';
import bleAdvertParserTest from './BleAdvertParser.test';
import radarLayoutHelperTest from './RadarLayoutHelper.test';
import radarDeviceLayoutTest from './RadarDeviceLayout.test';
import deviceEnvironmentTest from './DeviceEnvironment.test';

export default function testsuite() {
  localUnitTest();
  bleAdvertParserTest();
  radarLayoutHelperTest();
  radarDeviceLayoutTest();
  deviceEnvironmentTest();
}