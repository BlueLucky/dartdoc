// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/// The models used to represent Dart code
library dartdoc.models;

import 'package:analyzer/src/generated/ast.dart';
import 'package:analyzer/src/generated/element.dart';
import 'package:analyzer/src/generated/utilities_dart.dart' show ParameterKind;

import 'html_utils.dart';
import 'model_utils.dart';
import 'package_utils.dart';

abstract class ModelElement {
  final Element element;
  final Library library;
  final String source;

  ElementType _type;
  String _documentation;

  ModelElement(this.element, this.library, [this.source]);

  factory ModelElement.from(Element e, Library library) {
    if (e is ClassElement && !e.isEnum) {
      return new Class(e, library);
    }
    if (e is ClassElement && e.isEnum) {
      return new Enum(e, library);
    }
    if (e is FunctionElement) {
      return new ModelFunction(e, library);
    }
    if (e is FunctionTypeAliasElement) {
      return new Typedef(e, library);
    }
    if (e is FieldElement) {
      return new Field(e, library);
    }
    if (e is ConstructorElement) {
      return new Constructor(e, library);
    }
    if (e is MethodElement) {
      return new Method(e, library);
    }
    if (e is PropertyAccessorElement) {
      return new Accessor(e, library);
    }
    if (e is TopLevelVariableElement) {
      return new Variable(e, library);
    }
    if (e is TypeParameterElement) {
      return new TypeParameter(e, library);
    }
    if (e is DynamicElementImpl) {
      return new Dynamic(e, library);
    }
    throw "Unknown type ${e.runtimeType}";
  }

  String get documentation {
    if (_documentation != null) {
      return _documentation;
    }

    if (element == null) {
      return null;
    }

    _documentation = element.computeDocumentationComment();

    if (_documentation == null && canOverride()) {
      var overrideElement = getOverriddenElement();
      if (overrideElement != null) {
        _documentation = overrideElement.documentation;
      }
    }

    _documentation = stripComments(_documentation);

    return _documentation;
  }

  String resolveReferences(String docs) {
    NodeList<CommentReference> _getCommentRefs() {
      if (_documentation == null && canOverride()) {
        var melement = getOverriddenElement();
        if (melement.element.node != null &&
            melement.element.node is AnnotatedNode) {
          return (melement.element.node as AnnotatedNode).documentationComment.references;
        }
      }
      if (element.node is AnnotatedNode) {
        return (element.node as AnnotatedNode).documentationComment.references;
      }
      return null;
    }

    var commentRefs = _getCommentRefs();
    if (commentRefs == null || commentRefs.isEmpty) {
      return docs;
    }

    var matchChars = ['[', ']'];
    int lastWritten = 0;
    int index = docs.indexOf(matchChars[0]);
    StringBuffer buf = new StringBuffer();

    while (index != -1) {
      int end = docs.indexOf(matchChars[1], index + 1);
      if (end != -1) {
        if (index - lastWritten > 0) {
          buf.write(docs.substring(lastWritten, index));
        }
        String codeRef = docs.substring(index + matchChars[0].length, end);
        buf.write('[$codeRef]');
        var refElement = commentRefs.firstWhere(
            (ref) => ref.identifier.name == codeRef).identifier.staticElement;
        var refLibrary = new Library(refElement.library, package);
        var e = new ModelElement.from(refElement, refLibrary);
        var link = e.href;
        if (link != null) {
          buf.write('(${e.href})');
        }
        lastWritten = end + matchChars[1].length;
      } else {
        break;
      }
      index = docs.indexOf(matchChars[0], end + 1);
    }
    if (lastWritten < docs.length) {
      buf.write(docs.substring(lastWritten, docs.length));
    }
    print(buf.toString());
    return buf.toString();
  }

  String get htmlId => name;

  String toString() => '$runtimeType $name';

  List<String> getAnnotations() {
    List<ElementAnnotation> a = element.metadata;
    if (a.isNotEmpty) {
      return a.map((f) => f.element.name).toList();
    }
    return [];
  }

  bool canOverride() => element is ClassMemberElement;

  ModelElement getOverriddenElement() => null;

  String get name => element.name;

  bool get hasParameters =>
      element is ExecutableElement || element is FunctionTypeAliasElement;

  List<Parameter> get parameters {
    if (!hasParameters) {
      throw new StateError("$element does not have parameters");
    }
    List<ParameterElement> params;
    if (element is ExecutableElement) {
      // the as check silences the warning
      params = (element as ExecutableElement).parameters;
    }
    if (element is FunctionTypeAliasElement) {
      params = (element as FunctionTypeAliasElement).parameters;
    }

    return params.map((p) => new Parameter(p, library)).toList(growable: false);
  }

  bool get isExecutable => element is ExecutableElement;

  bool get isPropertyInducer => element is PropertyInducingElement;

  bool get isPropertyAccessor => element is PropertyAccessorElement;

  bool get isLocalElement => element is LocalElement;

  bool get isStatic {
    if (isPropertyInducer) {
      return (element as PropertyInducingElement).isStatic;
    }
    return false;
  }

  bool get isFinal => false;

  bool get isConst => false;

  ElementType get type => _type;

  /// Returns the [ModelElement] that encloses this.
  ModelElement getEnclosingElement() {
    // A class's enclosing element is a library, and there isn't a
    // modelelement for a library.
    if (element.enclosingElement != null &&
        element.enclosingElement is ClassElement) {
      return new ModelElement.from(element.enclosingElement, library);
    } else {
      return null;
    }
  }

//  String createLinkedSummary() {
//    if (isExecutable) {
//      ExecutableElement ex = (element as ExecutableElement);
//      String retType =
//          createLinkedReturnTypeName(new ElementType(ex.type, library));
//
//      return '${createLinkedName(this)}'
//          '($linkedParams)'
//          '${retType.isEmpty ? '' : ': $retType'}';
//    }
//    if (isPropertyInducer) {
//      PropertyInducingElement pe = (element as PropertyInducingElement);
//      StringBuffer buf = new StringBuffer();
//      buf.write('${createLinkedName(this)}');
//      String type = createLinkedName(pe.type == null
//          ? null
//          : new ModelElement.from(pe.type.element, library));
//      if (!type.isEmpty) {
//        buf.write(': $type');
//      }
//      return buf.toString();
//    }
//    return createLinkedName(this);
//  }

//  String createLinkedDescription() {
//    if (isExecutable && !(element is ConstructorElement)) {
//      ExecutableElement e = (element as ExecutableElement);
//      StringBuffer buf = new StringBuffer();
//
//      if (e.isStatic) {
//        buf.write('static ');
//      }
//
//      buf.write(createLinkedReturnTypeName(new ElementType(e.type, library)));
//      buf.write(
//          ' ${e.name}($linkedParams)');
//      return buf.toString();
//    }
//    if (isPropertyInducer) {
//      PropertyInducingElement e = (element as PropertyInducingElement);
//      StringBuffer buf = new StringBuffer();
//      if (e.isStatic) {
//        buf.write('static ');
//      }
//      if (e.isFinal) {
//        buf.write('final ');
//      }
//      if (e.isConst) {
//        buf.write('const ');
//      }
//
//      buf.write(createLinkedName(e.type == null
//          ? null
//          : new ModelElement.from(e.type.element, library)));
//      buf.write(' ${e.name}');
//
//      // write out any constant value
//      Object value = getConstantValue(e);
//
//      if (value != null) {
//        if (value is String) {
//          String str = stringEscape(value, "'");
//          buf.write(" = '${str}'");
//        } else if (value is num) {
//          buf.write(" = ${value}");
//        }
//        //NumberFormat.decimalPattern
//      }
//      return buf.toString();
//    }
//    return null;
//  }

  Package get package =>
      (this is Library) ? (this as Library).package : this.library.package;

  String get linkedName {
    if (!package.isDocumented(this)) {
      return htmlEscape(name);
    }
    if (name.startsWith('_')) {
      return htmlEscape(name);
    }
    Class c = getEnclosingElement();
    if (c != null && c.name.startsWith('_')) {
      return '${c.name}.${htmlEscape(name)}';
    }
    if (c != null && this is Constructor) {
      String name;
      if (name.isEmpty) {
        name = c.name;
      } else {
        name = '${c.name}.${htmlEscape(name)}';
      }
      return '<a href="${href}">${name}</a>';
    } else {
      return '<a href="${href}">${htmlEscape(name)}</a>';
    }
  }

  String get href {
    if (!package.isDocumented(this)) {
      return null;
    }
    return _href;
  }

  String get _href;

  // TODO: handle default values
  String get linkedParams {
    List<Parameter> allParams = parameters;

    List<Parameter> requiredParams =
        allParams.where((Parameter p) => !p.isOptional).toList();

    List<Parameter> positionalParams =
        allParams.where((Parameter p) => p.isOptionalPositional).toList();

    List<Parameter> namedParams =
        allParams.where((Parameter p) => p.isOptionalNamed).toList();

    StringBuffer buf = new StringBuffer();

    void renderParams(StringBuffer buf, List<Parameter> params) {
      for (int i = 0; i < params.length; i++) {
        Parameter p = params[i];
        if (i > 0) buf.write(', ');
        if (p.type != null && p.type.name != null) {
          String typeName = p.type.createLinkedName();
          if (typeName.isNotEmpty) {
            buf.write('<span class="type-annotation">$typeName</span> ');
          }
        }
        buf.write('<span class="parameter-name">${p.name}</span>');

        if (p.hasDefaultValue) {
          if (p.isOptionalNamed) {
            buf.write(': ');
          } else {
            buf.write('= ');
          }
          buf.write('<span class="default-value">${p.defaultValue}</span>');
        }
      }
    }

    renderParams(buf, requiredParams);

    if (positionalParams.isNotEmpty) {
      if (requiredParams.isNotEmpty) {
        buf.write(', ');
      }
      buf.write('[');
      renderParams(buf, positionalParams);
      buf.write(']');
    }

    if (namedParams.isNotEmpty) {
      if (requiredParams.isNotEmpty) {
        buf.write(', ');
      }
      buf.write('{');
      renderParams(buf, namedParams);
      buf.write('}');
    }

    return buf.toString();
  }
}

class Dynamic extends ModelElement {
  Dynamic(DynamicElementImpl element, Library library, [String source])
      : super(element, library, source);

  String get _href => throw new StateError('dynamic should not have an href');
}

class Package {
  String _rootDirPath;
  final List<Library> _libraries = [];
  bool _isSdk;
  String _sdkVersion;

  String get name =>
      _isSdk ? 'Dart API Reference' : getPackageName(_rootDirPath);

  String get version => _isSdk ? _sdkVersion : getPackageVersion(_rootDirPath);

  String get sdkVersion => _sdkVersion;

  String get description =>
      _isSdk ? 'Dart API Libraries' : getPackageDescription(_rootDirPath);

  List<Library> get libraries => _libraries;

  Package(Iterable<LibraryElement> libraryElements, this._rootDirPath,
      [this._sdkVersion, this._isSdk = false]) {
    libraryElements.forEach((element) {
      //   print('adding lib $element to package $name');
      _libraries.add(new Library(element, this));
    });
  }

  String toString() => 'Package $name, isSdk: $_isSdk';

  bool isDocumented(ModelElement e) {
    // TODO: review this logic. I'm compensating for what's probably a bug
    // see also ElementType and how an elementType is linked to a library
    if (e is Library) {
      return _libraries.any((lib) => lib.element == e.element);
    } else {
      return _libraries.any((lib) => lib.element == e.element.library);
    }
  }
}

class Library extends ModelElement {
  Package package;

  LibraryElement get _library => (element as LibraryElement);

  Library(LibraryElement element, this.package, [String source])
      : super(element, null, source);

  String get name {
    var source = _library.definingCompilationUnit.source;
    return source.isInSystemLibrary ? source.encoding : super.name;
  }

  bool get isInSdk => _library.isInSdk;

  List<Library> get exported => _library.exportedLibraries
      .map((lib) => new Library(lib, package))
      .toList();

  List<Variable> getVariables() {
    List<TopLevelVariableElement> elements = [];
    elements.addAll(_library.definingCompilationUnit.topLevelVariables);
    for (CompilationUnitElement cu in _library.parts) {
      elements.addAll(cu.topLevelVariables);
    }
    elements
      ..removeWhere(isPrivate)
      ..sort(elementCompare);
    return elements.map((e) => new Variable(e, this)).toList(growable: false);
  }

  List<Enum> getEnums() {
    List<ClassElement> enumClasses = _library.definingCompilationUnit.enums;
    for (CompilationUnitElement cu in _library.parts) {
      enumClasses.addAll(cu.enums);
    }
    return enumClasses
        .where(isPublic)
        .map((e) => new Enum(e, this))
        .toList(growable: false)..sort(elementCompare);
  }

  /// Returns getters and setters?
  List<Accessor> getAccessors() {
    List<PropertyAccessorElement> elements = [];
    elements.addAll(_library.definingCompilationUnit.accessors);
    for (CompilationUnitElement cu in _library.parts) {
      elements.addAll(cu.accessors);
    }
    elements
      ..removeWhere(isPrivate)
      ..sort(elementCompare);
    elements.removeWhere((e) => e.isSynthetic);
    return elements.map((e) => new Accessor(e, this)).toList();
  }

  List<Typedef> getTypedefs() {
    List<FunctionTypeAliasElement> elements = [];
    elements.addAll(_library.definingCompilationUnit.functionTypeAliases);
    for (CompilationUnitElement cu in _library.parts) {
      elements.addAll(cu.functionTypeAliases);
    }
    elements
      ..removeWhere(isPrivate)
      ..sort(elementCompare);
    return elements.map((e) => new Typedef(e, this)).toList();
  }

  List<ModelFunction> getFunctions() {
    List<FunctionElement> elements = [];
    elements.addAll(_library.definingCompilationUnit.functions);
    for (CompilationUnitElement cu in _library.parts) {
      elements.addAll(cu.functions);
    }
    elements
      ..removeWhere(isPrivate)
      // TODO not sure we want to sort these. Source order might be best.
      ..sort(elementCompare);
    return elements.map((e) {
      String eSource =
          (source != null) ? source.substring(e.node.offset, e.node.end) : null;
      return new ModelFunction(e, this, eSource);
    }).toList();
  }

  // TODO: rename this to getClasses
  List<Class> getTypes() {
    List<ClassElement> types = [];
    types.addAll(_library.definingCompilationUnit.types);
    for (CompilationUnitElement cu in _library.parts) {
      types.addAll(cu.types);
    }
    types
      ..removeWhere(isPrivate)
      ..sort(elementCompare);
    return types.map((e) => new Class(e, this, source)).toList();
  }

  List<Class> getExceptions() {
    LibraryElement coreLib =
        _library.importedLibraries.firstWhere((i) => i.name == 'dart.core');
    ClassElement exception = coreLib.getType('Exception');
    ClassElement error = coreLib.getType('Error');
    bool isExceptionOrError(Class t) {
      return t._cls.type.isSubtypeOf(exception.type) ||
          t._cls.type.isSubtypeOf(error.type);
    }
    return getTypes().where(isExceptionOrError).toList();
  }

  @override
  String get _href => '$name/index.html';
}

class Enum extends ModelElement {
  ClassElement get _enum => (element as ClassElement);

  Enum(ClassElement element, Library library, [String source])
      : super(element, library, source);

  String get _href => '${library.name}/$name.html';

  List<String> get names => _enum.fields.map((f) => f.name);
}

class Class extends ModelElement {
  List<ElementType> _mixins;
  ElementType _supertype;
  List<ElementType> _interfaces;

  ClassElement get _cls => (element as ClassElement);

  Class(ClassElement element, Library library, [String source])
      : super(element, library, source) {
    var p = library.package;
    _type = new ElementType(_cls.type, this);
    _mixins = _cls.mixins.map((f) {
      var lib = new Library(f.element.library, p);
      return new ElementType(f, new ModelElement.from(f.element, lib));
    }).toList();
    if (hasSupertype) {
      var lib = new Library(_cls.supertype.element.library, p);
      _supertype = new ElementType(
          _cls.supertype, new ModelElement.from(_cls.supertype.element, lib));
    }
    _interfaces = _cls.interfaces.map((f) {
      var lib = new Library(f.element.library, p);
      return new ElementType(f, new ModelElement.from(f.element, lib));
    }).toList();
  }

  bool get isAbstract => _cls.isAbstract;

  bool get hasSupertype =>
      _cls.supertype != null && _cls.supertype.element.supertype != null;

  ElementType get supertype => _supertype;

  List<ElementType> get mixins => _mixins;

  List<ElementType> get interfaces => _interfaces;

  List<Field> _getAllfields() {
    List<FieldElement> elements = _cls.fields.toList()
      ..removeWhere(isPrivate)
      ..sort(elementCompare);
    return elements.map((e) => new Field(e, library)).toList();
  }

  List<Field> getStaticFields() =>
      _getAllfields()..removeWhere((f) => !f.isStatic);

  List<Field> getInstanceFields() =>
      _getAllfields()..removeWhere((f) => f.isStatic);

  List<Accessor> getAccessors() {
    List<PropertyAccessorElement> accessors = _cls.accessors.toList()
      ..removeWhere(isPrivate)
      ..sort(elementCompare);
    accessors.removeWhere((e) => e.isSynthetic);
    return accessors.map((e) => new Accessor(e, library)).toList();
  }

  List<Constructor> getCtors() {
    List<ConstructorElement> c = _cls.constructors.toList()
      ..removeWhere(isPrivate)
      ..sort(elementCompare);
    return c.map((e) {
      var cSource =
          (source != null) ? source.substring(e.node.offset, e.node.end) : null;
      return new Constructor(e, library, cSource);
    }).toList();
  }

  List<Method> getMethods() {
    List<MethodElement> m = _cls.methods.toList()
      ..removeWhere(isPrivate)
      ..sort(elementCompare);
    return m.map((e) {
      var mSource =
          source != null ? source.substring(e.node.offset, e.node.end) : null;
      return new Method(e, library, mSource);
    }).toList();
  }

  @override
  String get _href => '${library.name}/$name.html';
}

class ModelFunction extends ModelElement {
  ModelFunction(FunctionElement element, Library library, [String contents])
      : super(element, library, contents) {
    var e = _func.type.element;
    _type = new ElementType(_func.type, this);
  }

  FunctionElement get _func => (element as FunctionElement);

  bool get isStatic => _func.isStatic;

  String get linkedReturnType {
    return type.createLinkedReturnTypeName();
  }

  @override
  String get _href => '${library.name}.html#$name';
}

class Typedef extends ModelElement {
  FunctionTypeAliasElement get _typedef =>
      (element as FunctionTypeAliasElement);

  Typedef(FunctionTypeAliasElement element, Library library)
      : super(element, library) {
    var e = _typedef.type.element;
    _type = new ElementType(_typedef.type, this);
  }

  // TODO: will the superclass version work?
//  String get linkedName {
//    StringBuffer buf = new StringBuffer();
//    buf.write(_typedef.name);
//    if (!_typedef.typeParameters.isEmpty) {
//      buf.write('<');
//      for (int i = 0; i < _typedef.typeParameters.length; i++) {
//        if (i > 0) {
//          buf.write(', ');
//        }
//        // TODO link this name
//        buf.write(_typedef.typeParameters[i].name);
//      }
//      buf.write('>');
//    }
//    return buf.toString();
//  }

  String get linkedReturnType {
    return type.createLinkedReturnTypeName();
  }

  String get _href => '${library.name}.html#$name';
}

class Field extends ModelElement {
  FieldElement get _field => (element as FieldElement);

  Field(FieldElement element, Library library) : super(element, library) {
    var e = _field.type.element;
    _type = new ElementType(
        _field.type, new ModelElement.from(e, new Library(e.library, package)));
  }

  bool get isFinal => _field.isFinal;

  bool get isConst => _field.isConst;

  String get _href {
    if (element.enclosingElement is ClassElement) {
      return '/${library.name}/${element.enclosingElement.name}.html#$name';
    } else if (element.enclosingElement is LibraryElement) {
      return '/${library.name}.html#$name';
    } else {
      throw new StateError(
          '$name is not in a class or library, instead a ${element.enclosingElement}');
    }
  }
}

class Constructor extends ModelElement {
  ConstructorElement get _constructor => (element as ConstructorElement);

  Constructor(ConstructorElement element, Library library, [String source])
      : super(element, library, source);

  @override
  String get _href =>
      '${library.name}/${_constructor.enclosingElement.name}.html#$name}';
}

class Method extends ModelElement {
  MethodElement get _method => (element as MethodElement);

  Method(MethodElement element, Library library, [String source])
      : super(element, library, source) {
    _type = new ElementType(_method.type, this);
  }

  Method getOverriddenElement() {
    ClassElement parent = element.enclosingElement;
    for (InterfaceType t in getAllSupertypes(parent)) {
      if (t.getMethod(element.name) != null) {
        return new Method(t.getMethod(element.name), library);
      }
    }
    return null;
  }

  @override
  String get _href => throw 'not implemented yet';
}

/// Getters and setters.
class Accessor extends ModelElement {
  PropertyAccessorElement get _accessor => (element as PropertyAccessorElement);

  Accessor(PropertyAccessorElement element, Library library)
      : super(element, library);

  bool get isGetter => _accessor.isGetter;

  @override
  String get _href => throw "not implemented yet";
}

/// Top-level variables. But also picks up getters and setters?
class Variable extends ModelElement {
  TopLevelVariableElement get _variable => (element as TopLevelVariableElement);

  Variable(TopLevelVariableElement element, Library library)
      : super(element, library) {
    if (hasGetter) {
      var t = _variable.getter.returnType;
      var lib = new Library(t.element.library, package);
      _type = new ElementType(t, new ModelElement.from(t.element, lib));
    } else {
      var s = _variable.setter.parameters.first.type;
      var lib = new Library(s.element.library, package);
      _type = new ElementType(s, new ModelElement.from(s.element, lib));
    }
  }

  bool get isFinal => _variable.isFinal;

  bool get isConst => _variable.isConst;

  String get linkedReturnType {
    return type.createLinkedName();
  }

  bool get hasGetter => _variable.getter != null;

  bool get hasSetter => _variable.setter != null;

  // TODO: check if this works for libraries and classes
  @override
  String get _href => throw 'Not implemented yet';
}

class Parameter extends ModelElement {
  Parameter(ParameterElement element, Library library)
      : super(element, library) {
    var t = _parameter.type;
    _type = new ElementType(t, new ModelElement.from(
        t.element, new Library(t.element.library, library.package)));
  }

  ParameterElement get _parameter => element as ParameterElement;

  bool get isOptional => _parameter.parameterKind.isOptional;

  bool get isOptionalPositional =>
      _parameter.parameterKind == ParameterKind.POSITIONAL;

  bool get isOptionalNamed => _parameter.parameterKind == ParameterKind.NAMED;

  bool get hasDefaultValue {
    return _parameter.defaultValueCode != null &&
        _parameter.defaultValueCode.isNotEmpty;
  }

  String get defaultValue {
    if (!hasDefaultValue) return null;
    return _parameter.defaultValueCode;
  }

  String toString() => element.name;

  @override
  String get _href => throw 'not implemented yet';
}

class TypeParameter extends ModelElement {
  TypeParameter(TypeParameterElement element, Library library)
      : super(element, library) {
    _type = new ElementType(_typeParameter.type, this);
  }

  TypeParameterElement get _typeParameter => element as TypeParameterElement;

  String toString() => element.name;

  @override
  String get _href => throw 'not implemented yet';
}

class ElementType {
  DartType _type;
  ModelElement _element;

  ElementType(this._type, this._element);

  String toString() => "$_type";

  bool get isDynamic => _type.isDynamic;

  bool get isParameterType => (_type is TypeParameterType);

  ModelElement get element => _element;

  String get name => _type.name;

  bool get isParameterizedType => (_type is ParameterizedType);

  String get _returnTypeName => (_type as FunctionType).returnType.name;

  bool get _hasReturnType => _type is FunctionType;

  ElementType get _returnType {
    var rt = (_type as FunctionType).returnType;
    return new ElementType(rt, new ModelElement.from(
        rt.element, new Library(rt.element.library, _element.package)));
  }
  ModelElement get returnElement {
    Element e = (_type as FunctionType).returnType.element;
    if (e == null) {
      return null;
    }
    Library lib = new Library(e.library, _element.package);
    return (new ModelElement.from(e, lib));
  }

  List<ElementType> get typeArguments =>
      (_type as ParameterizedType).typeArguments.map((f) {
    var lib = new Library(f.element.library, _element.package);
    return new ElementType(f, new ModelElement.from(f.element, lib));
  }).toList();

  String createLinkedName() {
    StringBuffer buf = new StringBuffer();

    if (isParameterType) {
      buf.write(name);
    } else {
      buf.write(element.linkedName);
    }

    // not TypeParameterType or Void or Union type
    if (isParameterizedType) {
      var typeArgs = typeArguments;
      if (!typeArguments.isEmpty &&
          (typeArguments.length > 1 ||
              typeArguments.first.toString() != 'dynamic')) {
        buf.write('&lt;');
        for (int i = 0; i < typeArguments.length; i++) {
          if (i > 0) {
            buf.write(', ');
          }
          ElementType t = typeArguments[i];
          buf.write(t.createLinkedName());
        }
        buf.write('&gt;');
      }
    }
    return buf.toString();
  }

  String createLinkedReturnTypeName() {
    if ((_type as FunctionType).returnType.element == null ||
        (_type as FunctionType).returnType.element.library == null) {
      if (_returnTypeName != null) {
        return _returnTypeName;
      } else {
        return '';
      }
    } else {
      return _returnType.createLinkedName();
    }
  }
}
