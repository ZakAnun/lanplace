@Entry
@Component
struct Index {
  @State message: string = '蓝域 AGC 仪器化测试运行中';

  build() {
    Row() {
      Column() {
        Text(this.message)
          .fontSize(18)
          .fontWeight(FontWeight.Medium)
      }
      .width('100%')
      .justifyContent(FlexAlign.Center)
    }
    .height('100%')
  }
}
