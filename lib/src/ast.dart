// Copyright (c) 2014 The Polymer Project Authors. All rights reserved.
// This code may only be used under the BSD style license found at http://polymer.github.io/LICENSE.txt
// The complete set of authors may be found at http://polymer.github.io/AUTHORS.txt
// The complete set of contributors may be found at http://polymer.github.io/CONTRIBUTORS.txt
// Code distributed by Google as part of the polymer project is also
// subject to an additional IP rights grant found at http://polymer.github.io/PATENTS.txt

/// AST nodes to represent the API of a Javascript polymer custom element. This
/// is parsed from documentation found in polymer elements and then it is used
/// to autogenerate a Dart API for them.
library custom_element_apigen.src.ast;

class FileSummary {
  List<Import> imports = [];
  Map<String, Element> elementsMap = {};
  Map<String, Mixin> mixinsMap = {};

  FileSummary();

  Iterable<Element> get elements => elementsMap.values;
  Iterable<Mixin> get mixins => mixinsMap.values;

  String toString() =>
      'imports: $imports, elements: $elements, mixins: $mixins';

  /// Splits this summary into multiple summaries based on [file_overrides]. The
  /// keys are file names and the values are classes that should live in that
  /// file. All remaining files will end up in the [null] key.
  Map<String, FileSummary> splitByFile(
      Map<String, List<String>> file_overrides) {
    if (file_overrides == null) return {null: this};

    var summaries = {};
    var remainingElements = new Map.from(elementsMap);
    var remainingMixins = new Map.from(mixinsMap);

    /// Removes [names] keys from [original] and returns a new [Map] with those
    /// removed values.
    Map<String, Class> removeFromMap(
        Map<String, Class> original, List<String> names) {
      var newMap = {};
      for (var name in names) {
        var val = original.remove(name);
        if (val != null) newMap[name] = val;
      }
      return newMap;
    }

    /// Builds a summary from this one given [classNames].
    FileSummary buildSummary(List<String> classNames) {
      var summary = new FileSummary();
      summary.imports = new List.from(imports);
      summary.elementsMap = removeFromMap(remainingElements, classNames);
      summary.mixinsMap = removeFromMap(remainingMixins, classNames);

      return summary;
    }

    file_overrides.forEach((String path, List<String> classNames) {
      summaries[path] = buildSummary(classNames);
    });

    var defaultSummary = new FileSummary();
    defaultSummary.imports = new List.from(imports);
    defaultSummary.elementsMap = remainingElements;
    defaultSummary.mixinsMap = remainingMixins;

    summaries[null] = defaultSummary;

    return summaries;
  }
}

/// Base class for any entry we parse out of the HTML files.
abstract class Entry {
  String toString() {
    var sb = new StringBuffer();
    _prettyPrint(sb);
    return sb.toString();
  }

  void _prettyPrint(StringBuffer sb);
}

/// Common information to most entries (element, property, method, etc).
abstract class NamedEntry {
  final String name;
  String description;

  NamedEntry(this.name, this.description);
}

/// An entry that has type information (like arguments and properties).
abstract class TypedEntry extends NamedEntry {
  String type;
  TypedEntry(name, desc, [this.type]) : super(name, desc);
}

/// An import to another html element.
class Import extends Entry {
  String importPath;
  Import(this.importPath);

  void _prettyPrint(StringBuffer sb) {
    sb.write('import: $importPath\n');
  }
}

class Class extends NamedEntry {
  String extendName;
  final Map<String, Property> properties = {};
  final List<Method> methods = [];

  Class(name, this.extendName) : super(name, '');

  void _prettyPrint(StringBuffer sb) {
    sb.write('$name:\n');
    sb.write('properties:');
    for (var p in properties.values) {
      sb.write('    - ');
      p._prettyPrint(sb);
      sb.write('\n');
    }
    sb.write('methods:');
    for (var m in methods) {
      sb.write('    - ');
      m._prettyPrint(sb);
      sb.write('\n');
    }
    sb.writeln('extends: $extendName');
  }

  String toString() {
    var message = new StringBuffer();
    _prettyPrint(message);
    return message.toString();
  }
}

class Mixin extends Class {
  Mixin(String name, String extendName) : super(name, extendName);

  _prettyPrint(StringBuffer sb) {
    sb.writeln('**Mixin**');
    super._prettyPrint(sb);
  }

  String toString() {
    var message = new StringBuffer();
    _prettyPrint(message);
    return message.toString();
  }
}

/// Data about a custom-element.
class Element extends Class {
  final List<String> mixins = [];

  Element(String name, String extendName) : super(name, extendName);

  void _prettyPrint(StringBuffer sb) {
    sb.writeln('**Element**');
    super._prettyPrint(sb);
    sb.writeln('  mixins:');
    for (var mixin in mixins) {
      sb.writeln('    - $mixin');
    }
    sb.writeln('  extends: $extendName');
  }

  String toString() {
    var message = new StringBuffer();
    _prettyPrint(message);
    return message.toString();
  }
}

/// Data about a property.
class Property extends TypedEntry {
  bool hasGetter;
  bool hasSetter;

  Property(name, desc, {this.hasGetter: false, this.hasSetter: false})
      : super(name, desc);

  void _prettyPrint(StringBuffer sb) {
    sb.write('$type $name;');
  }
}

/// Data about a method.
class Method extends TypedEntry {
  bool isVoid = true;
  List<Argument> args = [];
  List<Argument> optionalArgs = [];
  Method(name, desc) : super(name, desc);

  void _prettyPrint(StringBuffer sb) {
    if (isVoid) sb.write('void ');
    sb.write('$name(');

    bool first = true;
    for (var arg in args) {
      if (!first) sb.write(',');
      first = false;
      arg._prettyPrint(sb);
    }

    bool firstOptional = true;
    for (var arg in optionalArgs) {
      if (firstOptional) {
        if (!first) sb.write(',');
        sb.write('[');
      } else {
        sb.write(',');
      }
      first = false;
      firstOptional = false;
      arg._prettyPrint(sb);
    }
    if (!firstOptional) sb.write(']');

    sb.write(');');
  }
}

/// Collects name and type information for arguments.
class Argument extends TypedEntry {
  Argument(name, desc, type) : super(name, desc, type);

  void _prettyPrint(StringBuffer sb) {
    if (type != null) {
      sb
        ..write(type)
        ..write(' ');
    }
    sb.write(name);
  }
}
