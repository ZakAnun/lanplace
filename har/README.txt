Flutter HAR 产物目录（由 scripts/sync_flutter_har.sh 生成，勿手改）

需使用 OpenHarmony 适配版 Flutter（flutter_flutter），在 flutter_module 目录执行：
  flutter build har

脚本会将 build/ohos/har/ 下的 HAR 复制到本目录，供 oh-package.json5 引用。

Debug 期望文件：
  flutter_embedding_debug.har
  arm64_v8a_debug.har
  flutter_module.har

Release 构建时使用 --release，对应 *_release.har，并同步修改根目录 oh-package.json5 中的文件名。
