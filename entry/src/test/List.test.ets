import localUnitTest from './LocalUnit.test';
import bleAdvertParserTest from './BleAdvertParser.test';

export default function testsuite() {
  localUnitTest();
  bleAdvertParserTest();
}