// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

var foo = new JsThing('made in JS');
var aString = 'hello';
var aNum = 123;
var aBool = true;
var aDate = new Date(2014, 9, 4);
var a = null;

function JsThing(name) {
  this.name = name;
  this.bar = null;
  this.anonymous = {a:1,b:2};
}

JsThing.prototype.double = function(x) {
  return x+x;
}

JsThing.prototype.getName = function(o) {
  return o.name;
}

JsThing.prototype.getAnonymous = function() {
  return this.anonymous;
}

JsThing.prototype.setAnonymous = function(o) {
  this.anonymous = o;
}

JsThing.prototype.setBar = function(bar) {
  this.bar = bar;
}

JsThing.prototype.toString = function() {
  return this.name;
}

function JsThing2(name) {
  this.name = name;
  this.y = 42;
}

JsThing2.prototype = new JsThing();
JsThing2.prototype.constructor = JsThing2;

function createExportMe() {
  return new dart.test.library.ExportMe();
}

function createExportMeNamed(name) {
  return new dart.test.library.ExportMe.named(name);
}

function createExportMeNamed2(name) {
  return new dart.test.library.ExportMe.named2({'name': name});
}

function createExportMeOptional(name) {
  return new dart.test.library.ExportMe.named(name);
}

function isExportMe(e) {
  return e instanceof dart.test.library.ExportMe;
}

function isDartObject(o) {
  return o instanceof dart.Object;
}

function getName(hasName) {
  return hasName.name;
}

function setName(hasName, name) {
  hasName.name = name;
}

function callMethod(e) {
  return e.method();
}

function callMethod2(e, a) {
  return e.method2(a);
}

function callNamedArgs(e) {
  return e.namedArgs(1, {b: 2, c: 3});
}

function callOptionalArgs(e) {
  return e.optionalArgs(1, 2, 3);
}

function callOptionalArgs2(e) {
  return e.optionalArgs(1, 2);
}

function getGetter(e) {
  return e.getter;
}

function setSetter(e, v) {
  e.setter = v;
}

function roundTrip(e) {
  return e;
}

function isNull(value) {
  return value === null;
}
