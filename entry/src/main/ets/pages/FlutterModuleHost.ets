import { FlutterPage, FlutterView } from '@ohos/flutter_ohos';
import LanplaceFlutterEntry from '../flutter/LanplaceFlutterEntry';

/**
 * ArkUI container page for the embedded Flutter module (full-screen).
 * Open via router: url 'pages/FlutterModuleHost'
 */
@Entry
@Component
struct FlutterModuleHost {
  private flutterEntry: LanplaceFlutterEntry | null = null;
  private flutterView: FlutterView | undefined = undefined;

  aboutToAppear(): void {
    this.flutterEntry = new LanplaceFlutterEntry(getContext(this));
    this.flutterEntry.aboutToAppear();
    this.flutterView = this.flutterEntry.getFlutterView();
  }

  aboutToDisappear(): void {
    this.flutterEntry?.aboutToDisappear();
  }

  onPageShow(): void {
    this.flutterEntry?.onPageShow();
  }

  onPageHide(): void {
    this.flutterEntry?.onPageHide();
  }

  onBackPress(): boolean {
    this.flutterEntry?.onBackPress();
    return true;
  }

  build() {
    Stack() {
      FlutterPage({ viewId: this.flutterView?.getId() })
        .width('100%')
        .height('100%')
    }
    .width('100%')
    .height('100%')
  }
}
