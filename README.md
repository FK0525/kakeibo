# 家計簿アプリ

## セットアップ

```bash
cd kakeibo
flutter pub get
flutter run         # 実行
flutter build apk --release  # APKビルド
```

## 画面構成

| 画面 | 説明 |
|------|------|
| ホーム | 残高・プログレスバー・支出一覧 |
| 支出入力 | 金額・用途・要不・メモ・写真 |
| 支出詳細 | 詳細確認・削除・固定費の翌月金額変更 |
| 収入入力 | 25日以降に自動表示。金額のみ入力 |
| 特別収入 | ホーム右上から随時追加 |

## ロジック

- 使用可能金額 = 収入 ÷ 2（残り半分は貯金）
- 固定費は支出として入力、「毎月計上」チェックで翌月自動追加
- 25日以降アプリ起動で収入入力が自動ポップアップ

## ファイル構成

```
lib/
  main.dart
  models/
    expense.dart       # 支出モデル（カテゴリ・要不・メモ・毎月計上）
    monthly_data.dart  # 月次データ（収入・特別収入）
  providers/
    app_provider.dart  # 状態管理・永続化
  screens/
    home_screen.dart
    expense_input_screen.dart
    expense_detail_screen.dart
    income_input_screen.dart
```
