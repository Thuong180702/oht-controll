import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import '../../domain/entities/alarm_event.dart';

class EventLogExcelExporter {
  const EventLogExcelExporter._();

  static Future<File> export(List<AlarmEvent> events) async {
    final outputDir = await _downloadDirectory();
    final fileName = 'oht_event_log_${_fileTimestamp(DateTime.now())}.xlsx';
    final file = File('${outputDir.path}${Platform.pathSeparator}$fileName');
    final bytes = _buildWorkbook(events, DateTime.now());

    return file.writeAsBytes(bytes, flush: true);
  }

  static Future<Directory> _downloadDirectory() async {
    final home =
        Platform.environment['USERPROFILE'] ?? Platform.environment['HOME'];
    if (home != null && home.trim().isNotEmpty) {
      final downloads = Directory('$home${Platform.pathSeparator}Downloads');
      try {
        if (!await downloads.exists()) {
          await downloads.create(recursive: true);
        }
        return downloads;
      } catch (_) {
        // Fall back to the current process directory below.
      }
    }

    return Directory.current;
  }

  static Uint8List _buildWorkbook(List<AlarmEvent> events, DateTime createdAt) {
    final files = <String, Uint8List>{
      '[Content_Types].xml': _utf8(_contentTypesXml),
      '_rels/.rels': _utf8(_rootRelsXml),
      'docProps/app.xml': _utf8(_appPropsXml),
      'docProps/core.xml': _utf8(_corePropsXml(createdAt)),
      'xl/_rels/workbook.xml.rels': _utf8(_workbookRelsXml),
      'xl/workbook.xml': _utf8(_workbookXml),
      'xl/styles.xml': _utf8(_stylesXml),
      'xl/worksheets/sheet1.xml': _utf8(_sheetXml(events)),
    };

    return _zip(files);
  }

  static Uint8List _utf8(String value) =>
      Uint8List.fromList(utf8.encode(value));

  static String _sheetXml(List<AlarmEvent> events) {
    final lastRow = events.length + 1;
    final rows = StringBuffer()
      ..write(
        _row(1, const [
          'Timestamp',
          'Severity',
          'Message',
          'Event ID',
        ], style: 1),
      );

    for (var i = 0; i < events.length; i++) {
      final event = events[i];
      rows.write(
        _row(i + 2, [
          _formatTimestamp(event.timestamp),
          event.severity.name.toUpperCase(),
          event.message,
          event.id,
        ]),
      );
    }

    return '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
  <dimension ref="A1:D$lastRow"/>
  <sheetViews>
    <sheetView workbookViewId="0">
      <pane ySplit="1" topLeftCell="A2" activePane="bottomLeft" state="frozen"/>
    </sheetView>
  </sheetViews>
  <cols>
    <col min="1" max="1" width="22" customWidth="1"/>
    <col min="2" max="2" width="14" customWidth="1"/>
    <col min="3" max="3" width="80" customWidth="1"/>
    <col min="4" max="4" width="24" customWidth="1"/>
  </cols>
  <sheetData>
    $rows
  </sheetData>
  <autoFilter ref="A1:D$lastRow"/>
</worksheet>''';
  }

  static String _row(int rowIndex, List<String> values, {int style = 0}) {
    final cells = StringBuffer();
    for (var i = 0; i < values.length; i++) {
      final ref = '${_columnName(i + 1)}$rowIndex';
      final styleAttr = style > 0 ? ' s="$style"' : '';
      cells.write(
        '<c r="$ref" t="inlineStr"$styleAttr><is><t>${_xml(values[i])}</t></is></c>',
      );
    }
    return '<row r="$rowIndex">$cells</row>';
  }

  static String _columnName(int index) {
    var value = index;
    final chars = <String>[];
    while (value > 0) {
      value--;
      chars.insert(0, String.fromCharCode(65 + (value % 26)));
      value ~/= 26;
    }
    return chars.join();
  }

  static String _xml(String value) {
    return value
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&apos;');
  }

  static String _formatTimestamp(DateTime value) {
    final y = value.year.toString().padLeft(4, '0');
    final mo = value.month.toString().padLeft(2, '0');
    final d = value.day.toString().padLeft(2, '0');
    final h = value.hour.toString().padLeft(2, '0');
    final mi = value.minute.toString().padLeft(2, '0');
    final s = value.second.toString().padLeft(2, '0');
    return '$y-$mo-$d $h:$mi:$s';
  }

  static String _fileTimestamp(DateTime value) {
    final y = value.year.toString().padLeft(4, '0');
    final mo = value.month.toString().padLeft(2, '0');
    final d = value.day.toString().padLeft(2, '0');
    final h = value.hour.toString().padLeft(2, '0');
    final mi = value.minute.toString().padLeft(2, '0');
    final s = value.second.toString().padLeft(2, '0');
    return '$y$mo${d}_$h$mi$s';
  }

  static Uint8List _zip(Map<String, Uint8List> files) {
    final output = <int>[];
    final centralDirectory = <int>[];

    for (final entry in files.entries) {
      final nameBytes = utf8.encode(entry.key);
      final data = entry.value;
      final crc = _crc32(data);
      final localHeaderOffset = output.length;

      _u32(output, 0x04034b50);
      _u16(output, 20);
      _u16(output, 0);
      _u16(output, 0);
      _u16(output, 0);
      _u16(output, 0);
      _u32(output, crc);
      _u32(output, data.length);
      _u32(output, data.length);
      _u16(output, nameBytes.length);
      _u16(output, 0);
      output
        ..addAll(nameBytes)
        ..addAll(data);

      _u32(centralDirectory, 0x02014b50);
      _u16(centralDirectory, 20);
      _u16(centralDirectory, 20);
      _u16(centralDirectory, 0);
      _u16(centralDirectory, 0);
      _u16(centralDirectory, 0);
      _u16(centralDirectory, 0);
      _u32(centralDirectory, crc);
      _u32(centralDirectory, data.length);
      _u32(centralDirectory, data.length);
      _u16(centralDirectory, nameBytes.length);
      _u16(centralDirectory, 0);
      _u16(centralDirectory, 0);
      _u16(centralDirectory, 0);
      _u16(centralDirectory, 0);
      _u32(centralDirectory, 0);
      _u32(centralDirectory, localHeaderOffset);
      centralDirectory.addAll(nameBytes);
    }

    final centralDirectoryOffset = output.length;
    final centralDirectorySize = centralDirectory.length;
    output.addAll(centralDirectory);

    _u32(output, 0x06054b50);
    _u16(output, 0);
    _u16(output, 0);
    _u16(output, files.length);
    _u16(output, files.length);
    _u32(output, centralDirectorySize);
    _u32(output, centralDirectoryOffset);
    _u16(output, 0);

    return Uint8List.fromList(output);
  }

  static void _u16(List<int> output, int value) {
    output
      ..add(value & 0xff)
      ..add((value >> 8) & 0xff);
  }

  static void _u32(List<int> output, int value) {
    output
      ..add(value & 0xff)
      ..add((value >> 8) & 0xff)
      ..add((value >> 16) & 0xff)
      ..add((value >> 24) & 0xff);
  }

  static int _crc32(List<int> bytes) {
    var crc = 0xffffffff;
    for (final byte in bytes) {
      crc = _crc32Table[(crc ^ byte) & 0xff] ^ (crc >> 8);
    }
    return (crc ^ 0xffffffff) & 0xffffffff;
  }
}

final List<int> _crc32Table = List<int>.generate(256, (index) {
  var crc = index;
  for (var i = 0; i < 8; i++) {
    if ((crc & 1) == 1) {
      crc = 0xedb88320 ^ (crc >> 1);
    } else {
      crc >>= 1;
    }
  }
  return crc;
});

const String _contentTypesXml =
    '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
  <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
  <Default Extension="xml" ContentType="application/xml"/>
  <Override PartName="/docProps/app.xml" ContentType="application/vnd.openxmlformats-officedocument.extended-properties+xml"/>
  <Override PartName="/docProps/core.xml" ContentType="application/vnd.openxmlformats-package.core-properties+xml"/>
  <Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/>
  <Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>
  <Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>
</Types>''';

const String _rootRelsXml =
    '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>
  <Relationship Id="rId2" Type="http://schemas.openxmlformats.org/package/2006/relationships/metadata/core-properties" Target="docProps/core.xml"/>
  <Relationship Id="rId3" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/extended-properties" Target="docProps/app.xml"/>
</Relationships>''';

const String _appPropsXml =
    '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Properties xmlns="http://schemas.openxmlformats.org/officeDocument/2006/extended-properties" xmlns:vt="http://schemas.openxmlformats.org/officeDocument/2006/docPropsVTypes">
  <Application>OHT Control System</Application>
</Properties>''';

String _corePropsXml(DateTime createdAt) {
  final iso = createdAt.toUtc().toIso8601String();
  return '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<cp:coreProperties xmlns:cp="http://schemas.openxmlformats.org/package/2006/metadata/core-properties" xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:dcterms="http://purl.org/dc/terms/" xmlns:dcmitype="http://purl.org/dc/dcmitype/" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
  <dc:title>OHT Event Log</dc:title>
  <dc:creator>OHT Control System</dc:creator>
  <cp:lastModifiedBy>OHT Control System</cp:lastModifiedBy>
  <dcterms:created xsi:type="dcterms:W3CDTF">$iso</dcterms:created>
  <dcterms:modified xsi:type="dcterms:W3CDTF">$iso</dcterms:modified>
</cp:coreProperties>''';
}

const String _workbookRelsXml =
    '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/>
  <Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>
</Relationships>''';

const String _workbookXml =
    '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
  <sheets>
    <sheet name="Event Log" sheetId="1" r:id="rId1"/>
  </sheets>
</workbook>''';

const String _stylesXml =
    '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
  <fonts count="2">
    <font><sz val="11"/><name val="Calibri"/></font>
    <font><b/><sz val="11"/><color rgb="FFFFFFFF"/><name val="Calibri"/></font>
  </fonts>
  <fills count="3">
    <fill><patternFill patternType="none"/></fill>
    <fill><patternFill patternType="gray125"/></fill>
    <fill><patternFill patternType="solid"><fgColor rgb="FF1D4ED8"/><bgColor indexed="64"/></patternFill></fill>
  </fills>
  <borders count="2">
    <border><left/><right/><top/><bottom/><diagonal/></border>
    <border><left/><right/><top/><bottom style="thin"><color rgb="FFD9E2EC"/></bottom/><diagonal/></border>
  </borders>
  <cellStyleXfs count="1">
    <xf numFmtId="0" fontId="0" fillId="0" borderId="0"/>
  </cellStyleXfs>
  <cellXfs count="2">
    <xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0"/>
    <xf numFmtId="0" fontId="1" fillId="2" borderId="1" xfId="0" applyFont="1" applyFill="1" applyBorder="1"/>
  </cellXfs>
  <cellStyles count="1">
    <cellStyle name="Normal" xfId="0" builtinId="0"/>
  </cellStyles>
</styleSheet>''';
