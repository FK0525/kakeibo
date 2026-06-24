import 'dart:io';
import 'package:flutter/material.dart';

/// 登録した写真をタップしたときに全画面で表示するビューア。
/// ピンチでズーム、背景タップ／✕ボタンで閉じる。
class PhotoViewScreen extends StatelessWidget {
  final String path;
  final String heroTag;
  const PhotoViewScreen({super.key, required this.path, required this.heroTag});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: InteractiveViewer(
                minScale: 1,
                maxScale: 5,
                child: Center(
                  child: Hero(
                    tag: heroTag,
                    child: Image.file(File(path), fit: BoxFit.contain),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            right: 8,
            child: Material(
              color: Colors.black45,
              shape: const CircleBorder(),
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 26),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 写真を全画面表示で開く（半透明フェード遷移）。
void openPhotoView(BuildContext context, String path, String heroTag) {
  Navigator.of(context).push(PageRouteBuilder(
    opaque: false,
    barrierColor: Colors.black,
    transitionDuration: const Duration(milliseconds: 200),
    pageBuilder: (_, __, ___) => PhotoViewScreen(path: path, heroTag: heroTag),
    transitionsBuilder: (_, anim, __, child) =>
        FadeTransition(opacity: anim, child: child),
  ));
}
