// Copyright 2015 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

part of generate;

/// This class takes care of generating a temporary .mojoms files for packages
/// that need one but don't have one. It searches under [_mojomRootDir] for
/// .mojom files that have a DartPackage attribute. Then, we look for the
/// Dart package with that name under [_dartRootDir]. If the package can't be
/// found, we assume the DartPackage attribute is spurious and issue a warning.
class DotMojomsGenerator {
  static final Stopwatch _stopwatch = new Stopwatch();
  static Counter _mojomMs;

  Directory _mojomRootDir;
  Directory _dartRootDir;
  List<String> _skip;
  bool _verbose;
  Map<String, String> _packageLocations;

  DotMojomsGenerator(this._mojomRootDir, this._dartRootDir, this._skip,
      {bool verbose: false}) {
    _verbose = verbose;
    _packageLocations = new Map<String, String>();
    if (_mojomMs == null) {
      _mojomMs = new Counter("mojom searching",
          "Time(ms) searching for .mojom files with DartPackage annotations.");
      Metrics.register(_mojomMs);
    }
  }

  /// Generates .mojoms files for packages that need them, and returns the list
  /// of generated files.
  Future<List<File>> generate() async =>
      _findAndGenerateDotMojoms(await _findPackageMojoms());

  /// Look for .mojom files in the tree that have a DartPackage annotation.
  /// Return a mapping from package annotations to the paths of .mojom files
  /// with those annotations
  _findPackageMojoms() async {
    _stopwatch.start();
    Map<String, List<String>> mojoms = new Map<String, List<String>>();
    await for (var entry in _mojomRootDir.list(recursive: true)) {
      if (entry is! File) continue;
      if (_shouldSkip(entry)) continue;
      if (!isMojom(entry.path)) continue;
      String package = await _extractDartPackageAttribute(entry);
      if (package == null) continue;
      if (_verbose) print("findAndGenerateFromMojoms: found package $package.");
      if (mojoms.containsKey(package)) {
        mojoms[package].add(entry.path);
      } else {
        mojoms[package] = [entry.path];
      }
    }
    _stopwatch.stop();
    _mojomMs.value += _stopwatch.elapsedMilliseconds;
    _stopwatch.reset();
    return mojoms;
  }

  /// For the packages mentioned in [mojoms], generate a .mojoms file if one
  /// does not already exist.
  Future<List<File>> _findAndGenerateDotMojoms(
      Map<String, List<String>> mojoms) async {
    List<File> dotMojomsFiles = [];
    for (String package in mojoms.keys) {
      List<String> mojomPaths = mojoms[package];
      String importPath = _mojomRootDir.path;
      if (_verbose) print("import path for $package is $importPath");

      String dartSourcePath = await _findDartSourcePath(package);
      if (dartSourcePath == null) {
        stderr.writeln("WARNING: package $package not found");
        continue;
      }
      File dotMojomsFile = new File(path.join(dartSourcePath, '.mojoms'));
      if (await dotMojomsFile.exists()) {
        stderr.writeln("WARNING: package $package already has a .mojoms file. "
            "Overwriting.");
      }

      await _writeDotMojomsFile(dotMojomsFile, importPath, mojomPaths);
      dotMojomsFiles.add(dotMojomsFile);
    }
    return dotMojomsFiles;
  }

  /// Extract a DartPackage attribute from a .mojom file.
  Future<String> _extractDartPackageAttribute(File mojom) async {
    String contents = await mojom.readAsString();
    int dpIndex = contents.indexOf('DartPackage');
    if (dpIndex == -1) return null;

    // There must be a '[' before 'DartPackage', and there can't be a ']'
    // in between.
    int openSbIndex = contents.lastIndexOf('[', dpIndex);
    if (openSbIndex == -1) return null;
    int closeSbIndex = contents.lastIndexOf(']', dpIndex);
    if (closeSbIndex > openSbIndex) return null;

    int eqIndex = contents.indexOf('=', dpIndex);
    if (eqIndex == -1) return null;
    int openQuoteIndex = contents.indexOf('"', eqIndex);
    if (openQuoteIndex == -1) return null;
    int closeQuoteIndex = -1;
    int searchIndex = openQuoteIndex + 1;
    while (closeQuoteIndex == -1) {
      closeQuoteIndex = contents.indexOf('"', searchIndex);
      if (closeQuoteIndex == -1) break;
      if (contents[closeQuoteIndex - 1] == '\\') {
        searchIndex = closeQuoteIndex + 1;
        closeQuoteIndex = -1;
      }
    }
    if (closeQuoteIndex == -1) return null;
    return contents.substring(openQuoteIndex + 1, closeQuoteIndex);
  }

  /// Finds where the Dart package named [package] lives. Looks immediately
  /// under [_dartRootDir].
  Future<String> _findDartSourcePath(String package) async {
    var packagePath = path.join(_dartRootDir.path, package);
    Directory packageDir = new Directory(packagePath);
    if (_verbose) print("Found dart package: $packagePath");
    if (await packageDir.exists()) {
      return packageDir.path;
    } else {
      if (_verbose) print("\tNot found");
    }
  }

  /// Write a .mojoms file [dotMojomsFile] as:
  /// root: [importPath]/
  /// [mojomPaths]
  _writeDotMojomsFile(
      File dotMojomsFile, String importPath, List<String> mojomPaths) async {
    IOSink sink = dotMojomsFile.openWrite();
    sink.writeln("root: $importPath/");
    for (var mojom in mojomPaths) {
      String relativePath = path.relative(mojom, from: importPath);
      sink.writeln(relativePath);
    }
    await sink.close();
  }

  bool _shouldSkip(File f) => containsPrefix(f.path, _skip);
}
