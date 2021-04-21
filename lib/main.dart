import 'dart:developer';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:dotted_border/dotted_border.dart';
import 'package:flushbar/flushbar_helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'package:image/image.dart' as ig;

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Take Photo And Crop',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  CameraController controller;
  ImageStream takedPhoto;
  ImageStreamListener imageListener;
  File result;
  bool viewImage = false;
  String filePathCompressed;

  double widthScreen;

  File copyCrop(ig.Image src, int wImg, int hImg) {
    int wFrame = (widthScreen - 32 - 32).toInt();
    int hFrame = (widthScreen - 32 - 32) ~/ 2;

    int x = (wImg - wFrame) ~/ 2;
    int y = (hImg - hFrame) ~/ 2;

    print(
        "src: ${src.width}-${src.height}, wFrame: $wFrame, hFrame: $hFrame, wImg: $wImg, hImg: $hImg, x: $x, y: $y");

    ig.Image dst = ig.Image(wFrame, hFrame,
        channels: src.channels, exif: src.exif, iccp: src.iccProfile);

    for (int yi = 0, sy = y; yi < hFrame; yi++, sy++) {
      for (int xi = 0, sx = x; xi < wFrame; xi++, sx++) {
        log("$xi, $yi, src.getPixel($sx, $sy)");
        dst.setPixel(xi, yi, src.getPixel(sx, sy));
        log("$xi, $yi, src.getPixel($sx, $sy)");
      }
    }

    var file = File.fromRawPath(dst.getBytes());

    return file;
  }

  void resetPhoto() {
    setState(() {
      result = null;
      viewImage = false;
    });
    log("See viewImage $viewImage");
  }

  void scanPhoto() async {
    if (controller.value.isInitialized) {
      try {
        final Directory extDir = await getApplicationDocumentsDirectory();
        final String dirPath = '${extDir.path}/flp/pictures';
        if (Directory(dirPath).existsSync()) {
          Directory(dirPath).deleteSync(recursive: true);

          /// Delete file to memory disk space
        }
        await Directory(dirPath).create(recursive: true);
        String time = DateTime.now().millisecondsSinceEpoch.toString();
        final String filePath = '$dirPath/$time.jpg';
        filePathCompressed = '$dirPath/${time}_compressed.jpg';
        await controller.takePicture(filePath);

        if (takedPhoto != null) {
          if (imageListener != null) {
            takedPhoto.removeListener(imageListener);
            takedPhoto = null;
            imageListener = null;
          }
        }
        takedPhoto = Image(image: FileImage(File(filePath)))
            .image
            .resolve(ImageConfiguration());
        imageListener = ImageStreamListener((info, _) async {
          try {
            int width = info.image.width;
            int height = info.image.height;
            // result = await compressPhoto(width, height, filePath);
            await cropPhoto(width, height, filePath);
            if (result != null) {
              viewImage = true;
            } else {
              viewImage = false;
            }

            setState(() {});
          } catch (e) {
            print(e);
            FlushbarHelper.createError(message: e).show(context);
          }
        });
        takedPhoto.addListener(imageListener);
      } catch (e) {
        log("Kesalahan 002 ${e.toString()}");
        FlushbarHelper.createError(message: "Terjadi Kesalahan 002")
            .show(context);
      }
    }
  }

  Future<File> compressPhoto(int width, int height, String filePath) async {
    return await FlutterImageCompress.compressAndGetFile(
      filePath,
      filePathCompressed,
      quality: 100,
      minWidth: width,
      minHeight: height,
      rotate: 1,
      autoCorrectionAngle: true,
    );
  }

  cropPhoto(int width, int height, String filePath) async {
    int cameraWidthDisplay = (widthScreen - 32).toInt();

    double scale = width / cameraWidthDisplay;
    int wFrame = ((cameraWidthDisplay - 32) * scale).toInt();
    int hFrame = ((cameraWidthDisplay - 32) * scale) ~/ 2;

    int x = (width - wFrame) ~/ 2;
    int y = (height - hFrame) ~/ 2;
    result = File(filePathCompressed);
    File originalFile = File(filePath);
    print("Original File Size: ${((await originalFile.length()) / 1024).toStringAsFixed(2)} KB");
    ig.Image src = ig.decodeImage(File(filePath).readAsBytesSync());
    ig.Image copyCrop = ig.copyCrop(src, x, y, wFrame, hFrame);
    List<int> jpg = ig.encodeJpg(copyCrop);
    result.writeAsBytesSync(jpg);
    print("Cropped File Size: ${((await result.length()) / 1024).toStringAsFixed(2)} KB");
  }

  @override
  void initState() {
    availableCameras().then((cameras) {
      controller = CameraController(cameras[0], ResolutionPreset.max);
      controller.initialize().then((_) {
        if (!mounted) {
          return;
        }
        setState(() {});
      });
    });
    super.initState();
  }

  @override
  void dispose() {
    controller?.dispose();
    if (imageListener != null) {
      takedPhoto?.removeListener(imageListener);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    widthScreen = MediaQuery.of(context).size.width;

    return Scaffold(
      appBar: AppBar(
        title: Text("Take and CROP"),
      ),
      body: SingleChildScrollView(
        child: Container(
          margin: EdgeInsets.all(32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              SizedBox(height: 16),
              Text(
                "Ambil Foto",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: Colors.grey,
                ),
              ),
              SizedBox(height: 16),
              Text(
                "Foto Akan Terpotong sesuai yang tampil saja",
                style: TextStyle(color: Colors.grey),
              ),
              SizedBox(height: 16),
              Container(
                width: widthScreen - 32,
                height: widthScreen - 32,
                color: Colors.grey,
                child: (controller?.value?.isInitialized == null ||
                        controller?.value?.isInitialized == false)
                    ? Container()
                    : ClipRect(
                        child: OverflowBox(
                          alignment: Alignment.center,
                          child: FittedBox(
                            fit: BoxFit.fitWidth,
                            child: Container(
                              width: widthScreen - 32,
                              height: (widthScreen - 32) /
                                  controller.value.aspectRatio,
                              child: Stack(
                                children: [
                                  Visibility(
                                    child: !viewImage
                                        ? Positioned.fill(
                                            child: CameraPreview(controller))
                                        : Positioned.fill(
                                            child: Stack(
                                              children: [
                                                Container(
                                                  color: Colors.black,
                                                ),
                                                Container(
                                                  alignment: Alignment.center,
                                                  child: Image.file(
                                                    result,
                                                    width: widthScreen - 32 - 32,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                  ),
                                  Align(
                                    alignment: Alignment.center,
                                    child: Container(
                                      width: widthScreen - 32 - 32,
                                      height: (widthScreen - 32 - 32) / 2,
                                      child: DottedBorder(
                                        child: SizedBox(
                                          width: widthScreen - 32 - 32,
                                          height: (widthScreen - 32 - 32) / 2,
                                        ),
                                        color: Colors.white,
                                        strokeWidth: 2,
                                        strokeCap: StrokeCap.square,
                                        padding: EdgeInsets.all(5),
                                        dashPattern: [6, 5],
                                      ),
                                    ),
                                  )
                                ],
                              ), // this is my CameraPreview
                            ),
                          ),
                        ),
                      ),
              ),
              SizedBox(height: 32),
              Center(
                child: SizedBox(
                  height: 45,
                  width: widthScreen,
                  child: Visibility(
                    child: !viewImage
                        ? RaisedButton(
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(50)),
                            color: Colors.blue,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: <Widget>[
                                Text("Ambil Foto",
                                    style: TextStyle(color: Colors.white)),
                              ],
                            ),
                            onPressed: () {
                              scanPhoto();
                            },
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: <Widget>[
                              SizedBox(
                                width: widthScreen / 3,
                                height: 50,
                                child: RaisedButton(
                                  shape: RoundedRectangleBorder(
                                      side: BorderSide(
                                        color: Colors.blue,
                                      ),
                                      borderRadius: BorderRadius.circular(50)),
                                  color: Colors.white,
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: <Widget>[
                                      Text("Tidak",
                                          style: TextStyle(color: Colors.blue)),
                                    ],
                                  ),
                                  onPressed: () {
                                    resetPhoto();
                                  },
                                ),
                              ),
                              SizedBox(
                                width: 30,
                              ),
                              SizedBox(
                                width: widthScreen / 3,
                                height: 50,
                                child: RaisedButton(
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(50)),
                                  color: Colors.blue,
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: <Widget>[
                                      Text("Ya",
                                          style:
                                              TextStyle(color: Colors.white)),
                                    ],
                                  ),
                                  onPressed: () {
                                    resetPhoto();
                                  },
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ), // This trailing comma makes auto-formatting nicer for build methods.
    );
  }
}
