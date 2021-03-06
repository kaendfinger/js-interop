// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library js.transformer.dart_initializer_generator;

import 'package:js/src/js_elements.dart';
import 'package:js/src/transformer/utils.dart';
import 'package:logging/logging.dart';
import 'package:quiver/iterables.dart';

final _logger = new Logger('js.transformer.dart_initializer_generator');

class DartInitializerGenerator {
  final String libraryName;
  final String libraryPath;
  final JsElements jsElements;

  final buffer = new StringBuffer();

  DartInitializerGenerator(this.libraryName, this.libraryPath, this.jsElements);

  /**
   * Returns the transformed source.
   */
  String generate() {
    buffer.write(
'''
library ${libraryName}__init_js__;

import 'dart:js' as js;
import '${libraryPath}';
import 'package:js/src/js_impl.dart' as $JS_PREFIX;

final _obj = js.context['Object'];

initializeJavaScriptLibrary() {
''');

    jsElements.proxies.forEach((Proxy proxy) {
      if (proxy.constructor == null) return;
      var name = proxy.name;
      buffer.writeln("  $JS_PREFIX.registerFactoryForJsConstructor("
          "$JS_PREFIX.getPath('${proxy.constructor}'), "
          "($JS_PREFIX.JsObject o) => new $name.created(o));");
    });

    buffer.writeln("  var lib = $JS_PREFIX.context['dart'];");

    jsElements.exportedLibraries.values.forEach(_generateLibraryExportCall);

    buffer.writeln('}');

    jsElements.exportedLibraries.values.forEach(_generateLibraryExportMethod);

    return buffer.toString();
  }

  _generateLibraryExportCall(ExportedLibrary library) {
    buffer.writeln("  _export_${library.getPath('_')}(lib);");
  }

  _generateLibraryExportMethod(ExportedLibrary library) {
    buffer.writeln(
'''

void _export_${library.getPath('_')}($JS_PREFIX.JsObject parent) {
  js.JsObject lib = parent['${library.getPath("']['")}'];
''');

    library.declarations.values.forEach(_generateDeclarationExportCall);
    buffer.writeln('}');
    library.declarations.values.forEach(_generateDeclarationExport);
  }

  void _generateDeclarationExportCall(ExportedElement element) {
    if (element is ExportedClass) {
      buffer.writeln("  _export_${element.getPath('_')}(lib);");
    }
  }

  void _generateDeclarationExport(ExportedElement element) {
    if (element is ExportedClass) {
      _generateClass(element);
    }
  }

  void _generateClass(ExportedClass c) {
    buffer.writeln(
'''

void _export_${c.getPath('_')}($JS_PREFIX.JsObject parent) {
  var constructor = parent['${c.name}'];
  $JS_PREFIX.registerJsConstructorForType(${c.name},
      constructor['_wrapDartObject']);
  var prototype = constructor['prototype'];
''');

    c.children.values.forEach(_generateClassMember);

    buffer.writeln("}");
  }

  void _generateClassMember(ExportedElement e) {
    if (e is ExportedConstructor) {
      _generateConstructor(e);
    } else if (e is ExportedMethod) {
      _generateMethod(e);
    } else if (e is ExportedProperty) {
      _generateProperty(e);
    }
  }

  void _generateConstructor(ExportedConstructor c) {
    var constructorName = c.name == '' ? '_new' : '_new_${c.name}';
    var dartParameters = formatParameters(c.parameters, _dartCallFormatter);
    var jsParameters = formatParameters(c.parameters, _jsSignatureFormatter());
    var namedPart = c.name == '' ? '' : '.${c.name}';
    buffer.writeln("  constructor['${constructorName}'] = ($jsParameters) => "
        "new ${c.parent.name}$namedPart($dartParameters);");
  }

  void _generateMethod(ExportedMethod c) {
    if (c.isStatic) return; // TODO: static method support
    var dartParameters = formatParameters(c.parameters, _dartCallFormatter);
    var jsParameters =
        formatParameters(c.parameters, _jsSignatureFormatter(withThis: true));
    if (c.jsifyReturn) {
      buffer.writeln(
'''
  // method ${c.name}
  prototype['${c.name}'] = new js.JsFunction.withThis(($jsParameters) {
    return  $JS_PREFIX.jsify(
        ($JS_PREFIX.toDart($JS_THIS_REF) as ${c.parent.name})
            .${c.name}($dartParameters));
  });
''');
    } else {
      buffer.writeln(
'''
  // method ${c.name}
  prototype['${c.name}'] = new js.JsFunction.withThis(($jsParameters) {
    return  ($JS_PREFIX.toDart($JS_THIS_REF) as ${c.parent.name})
        .${c.name}($dartParameters);
  });
''');
    }
  }

  void _generateProperty(ExportedProperty f) {
    if (f.isStatic) return; // TODO: static field support
    var name = f.name;
    var className = f.parent.name;
    buffer.writeln("  _obj.callMethod('defineProperty', [prototype, '$name', "
        "new js.JsObject.jsify({");
    if (f.hasGetter) {
      if (f.jsify) {
        buffer.writeln("    'get': new js.JsFunction.withThis("
            "(o) => $JS_PREFIX.jsify("
                "(o[$JS_PREFIX.DART_OBJECT_PROPERTY] as $className).$name)),");
      } else {
        buffer.writeln("    'get': new js.JsFunction.withThis("
            "(o) => "
                "(o[$JS_PREFIX.DART_OBJECT_PROPERTY] as $className).$name),");
      }
    }
    if (f.hasSetter) {
      buffer.writeln("    'set': new js.JsFunction.withThis("
          "(o, v) => (o[$JS_PREFIX.DART_OBJECT_PROPERTY] as $className).$name "
          "= v),");
    }
    buffer.writeln("  })]);");
  }

}

/**
 * Formats parameters for use as a Dart closure passed to JavaScript.
 *
 * Examples:
 *  * (a) -> "a"
 *  * (a, [b]) -> "a, [b]"
 *  * (a, {b, c}) -> "a, [__js_named_parameter_map__]"
 *
 * If [withThis] is true:
 *   * (a) -> "__js_this_ref__, a"
 */
_jsSignatureFormatter({bool withThis: false}) =>
    (requiredParameters, optionalParameters, namedParameters) {
      var jsParameterList = withThis ? [JS_THIS_REF] : [];
      jsParameterList.addAll(requiredParameters);
      if (optionalParameters.isNotEmpty) {
        jsParameterList.add('[' + optionalParameters.join(', ') + ']');
      } else if (namedParameters.isNotEmpty) {
        jsParameterList.add('[$JS_NAMED_PARAMETERS]');
      }
      return jsParameterList.join(', ');
    };

/**
 * Formats parameters for use as arguments to a Dart closure invocation,
 * with parameters were formatted by [_jsSignatureFormatter].
 *
 * Examples:
 *  * (a) -> "a"
 *  * (a, [b]) -> "a, b"
 *  * (a, {b}) -> "a, b: getOptionalArg(__js_named_parameter_map__, 'b')"
 */
_dartCallFormatter(requiredParameters, optionalParameters, namedParameters) {
  var dartNamedParameters = namedParameters.map((name) =>
      "${name}: $JS_PREFIX.getOptionalArg($JS_NAMED_PARAMETERS, '${name}')");
  return concat([
          requiredParameters,
          optionalParameters,
          dartNamedParameters])
      .join(', ');
}
