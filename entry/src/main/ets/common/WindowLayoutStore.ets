export class WindowLayoutStore {
  static readonly WIDTH_KEY: string = 'mainWindowWidth';
  static readonly HEIGHT_KEY: string = 'mainWindowHeight';

  static applySize(width: number, height: number): void {
    AppStorage.setOrCreate(WindowLayoutStore.WIDTH_KEY, width);
    AppStorage.setOrCreate(WindowLayoutStore.HEIGHT_KEY, height);
  }
}
