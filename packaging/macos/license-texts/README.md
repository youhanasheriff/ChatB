# Supplemental license texts

Used by `collect-notices.py` when a published Rust crate declares a license but
omits the corresponding standalone text. Existing packaged notices always take
precedence. Author metadata and available source copyright lines are preserved.

- Apache-2.0: standard text from the pinned serde 1.0.228 package, `LICENSE-APACHE`.
- MPL-2.0: standard text from option-ext 0.2.0, `LICENSE.txt`.
- MIT: standard grant/conditions from serde 1.0.228, without serde-specific
  copyright attribution; each package's own authors/copyrights are listed by
  the collector.
- cookie-factory 0.3.3: exact repository `LICENSES/MIT.txt` at
  `d36b805dbd7dd65f2df947235c5bcc573afe2c76`, from
  <https://github.com/rust-bakery/cookie-factory/blob/d36b805dbd7dd65f2df947235c5bcc573afe2c76/LICENSES/MIT.txt>.

For crates offering Apache-2.0 as an alternative and missing their own notice
files, the collector selects Apache-2.0. For priority-queue it selects MPL-2.0
and records the exact unmodified source archive URL.
