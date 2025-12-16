load("//js/private:js_component.bzl", _js_component = "js_component")
load("//js/private:plugin.bzl", _gerrit_js_bundle = "gerrit_js_bundle", _polygerrit_plugin = "polygerrit_plugin")
load("//js/private:terser.bzl", _terser = "terser")

gerrit_js_bundle = _gerrit_js_bundle
js_component = _js_component
polygerrit_plugin = _polygerrit_plugin
terser = _terser
