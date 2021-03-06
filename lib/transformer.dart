// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library js.transformer;

import 'package:barback/barback.dart' show Asset, AssetId, BarbackSettings,
    Transform, Transformer, TransformerGroup;
import 'package:code_transformers/resolver.dart';

import 'src/transformer/library_transformer.dart';
import 'src/transformer/mock_sdk.dart' as mock_sdk show sources;

/**
 * The JS transformer, which internally runs several phases that will:
 *   * Generate typed JavaScript proxies for classes extending JsInterface
 *   * TODO: Export Dart code annotated with @Export
 */
class LibraryTransformerGroup implements TransformerGroup {
  final Resolvers _resolvers;

  final Iterable<Iterable> phases;

  LibraryTransformerGroup(Resolvers resolvers)
      : _resolvers = resolvers,
        phases = [
          [new LibraryTransformer(resolvers)],
        ];

  LibraryTransformerGroup.asPlugin(BarbackSettings settings)
      : this(new Resolvers.fromMock(mock_sdk.sources));
}
