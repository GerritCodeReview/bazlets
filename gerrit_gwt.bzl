load("//tools:maven_jar.bzl", "maven_jar")

GWT_VER = "2.8.0"

OW2_VER = "5.1"

def gerrit_gwt():
  maven_jar(
    name = 'gwt_user',
    artifact = 'com.google.gwt:gwt-user:' + GWT_VER,
    sha1 = '518579870499e15531f454f35dca0772d7fa31f7',
    attach_source = False,
  )
  maven_jar(
    name = 'gwt_dev',
    artifact = 'com.google.gwt:gwt-dev:' + GWT_VER,
    sha1 = 'f160a61272c5ebe805cd2d3d3256ed3ecf14893f',
    attach_source = False,
  )
  maven_jar(
    name = 'javax_validation',
    artifact = 'javax.validation:validation-api:1.0.0.GA',
    sha1 = 'b6bd7f9d78f6fdaa3c37dae18a4bd298915f328e',
    src_sha1 = '7a561191db2203550fbfa40d534d4997624cd369',
  )
  maven_jar(
    name = 'jsinterop_annotations',
    artifact = 'com.google.jsinterop:jsinterop-annotations:1.0.0',
    sha1 = '23c3a3c060ffe4817e67673cc8294e154b0a4a95',
    src_sha1 = '5d7c478efbfccc191430d7c118d7bd2635e43750',
  )
  maven_jar(
    name = 'ant_artifact',
    artifact = 'ant:ant:1.6.5',
    sha1 = '7d18faf23df1a5c3a43613952e0e8a182664564b',
    src_sha1 = '9e0a847494563f35f9b02846a1c1eb4aa2ee5a9a',
  )
  maven_jar(
    name = 'colt_artifact',
    artifact = 'colt:colt:1.2.0',
    attach_source = False,
    sha1 = '0abc984f3adc760684d49e0f11ddf167ba516d4f',
  )
  maven_jar(
    name = 'tapestry_artifact',
    artifact = 'tapestry:tapestry:4.0.2',
    attach_source = False,
    sha1 = 'e855a807425d522e958cbce8697f21e9d679b1f7',
  )
  maven_jar(
    name = 'w3c_css_sac',
    artifact = 'org.w3c.css:sac:1.3',
    attach_source = False,
    sha1 = 'cdb2dcb4e22b83d6b32b93095f644c3462739e82',
  )
  maven_jar(
    name = 'ow2_asm',
    artifact = 'org.ow2.asm:asm:' + OW2_VER,
    sha1 = '5ef31c4fe953b1fd00b8a88fa1d6820e8785bb45',
  )
  maven_jar(
    name = 'ow2_asm_analysis',
    artifact = 'org.ow2.asm:asm-analysis:' + OW2_VER,
    sha1 = '6d1bf8989fc7901f868bee3863c44f21aa63d110',
  )
  maven_jar(
    name = 'ow2_asm_commons',
    artifact = 'org.ow2.asm:asm-commons:' + OW2_VER,
    sha1 = '25d8a575034dd9cfcb375a39b5334f0ba9c8474e',
  )
  maven_jar(
    name = 'ow2_asm_tree',
    artifact = 'org.ow2.asm:asm-tree:' + OW2_VER,
    sha1 = '87b38c12a0ea645791ead9d3e74ae5268d1d6c34',
  )
  maven_jar(
    name = 'ow2_asm_util',
    artifact = 'org.ow2.asm:asm-util:' + OW2_VER,
    sha1 = 'b60e33a6bd0d71831e0c249816d01e6c1dd90a47',
  )
  native.bind(
    name = 'gwt-user',
    actual = '@gwt_user//jar')
  native.bind(
    name = 'gwt-dev',
    actual = '@gwt_dev//jar')
  native.bind(
    name = 'gwt-user-neverlink',
    actual = '@gwt_user//jar:neverlink')
  native.bind(
    name = 'gwt-dev-neverlink',
    actual = '@gwt_dev//jar:neverlink')
  native.bind(
    name = 'javax-validation',
    actual = '@javax_validation//jar')
  native.bind(
    name = 'javax-validation-src',
    actual = '@javax_validation//src')
  native.bind(
    name = 'jsinterop-annotations',
    actual = '@jsinterop_annotations//jar')
  native.bind(
    name = 'jsinterop-annotations-src',
    actual = '@jsinterop_annotations//src')
  native.bind(
    name = 'ant',
    actual = '@ant_artifact//jar')
  native.bind(
    name = 'colt',
    actual = '@colt_artifact//jar')
  native.bind(
    name = 'tapestry',
    actual = '@tapestry_artifact//jar')
  native.bind(
    name = 'w3c-css-sac',
    actual = '@w3c_css_sac//jar')
  native.bind(
    name = 'ow2-asm',
    actual = '@ow2_asm//jar',
  )
  native.bind(
    name = 'ow2-asm-analysis',
    actual = '@ow2_asm_analysis//jar',
  )
  native.bind(
    name = 'ow2-asm-commons',
    actual = '@ow2_asm_commons//jar',
  )
  native.bind(
    name = 'ow2-asm-tree',
    actual = '@ow2_asm_tree//jar',
  )
  native.bind(
    name = 'ow2-asm-util',
    actual = '@ow2_asm_util//jar')
