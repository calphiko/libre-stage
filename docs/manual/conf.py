# Configuration file for the Sphinx documentation builder.
# https://www.sphinx-doc.org/en/master/usage/configuration.html

import json
import os
import sys

# Make the backend package importable for autodoc
_root = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
sys.path.insert(0, _root)

# -- Read version from version.json ------------------------------------------
_root = os.path.join(os.path.dirname(__file__), '..', '..')
with open(os.path.join(_root, 'version.json'), encoding='utf-8') as _f:
    _vdata = json.load(_f)

release = _vdata.get('release', 'v0.0.0')          # e.g. "v0.3.5"
version = '.'.join(release.lstrip('v').split('.')[:2])  # e.g. "0.3"

# -- Project information -----------------------------------------------------
project = f'libreStage {release}'
author = 'libreStage contributors'
copyright = '2026, libreStage contributors'

# -- General configuration ---------------------------------------------------
extensions = [
    'sphinx_copybutton',
    'sphinx.ext.autodoc',
    'sphinx.ext.napoleon',
    'sphinx.ext.viewcode',
    'sphinx.ext.intersphinx',
]

# autodoc settings
autodoc_default_options = {
    'members': True,
    'undoc-members': False,
    'show-inheritance': True,
    'member-order': 'bysource',
}
autodoc_typehints = 'description'
autodoc_typehints_description_target = 'documented'
napoleon_google_docstring = True
napoleon_numpy_docstring = False
napoleon_include_init_with_doc = False
napoleon_use_rtype = True

# intersphinx: link to Python standard library docs
intersphinx_mapping = {
    'python': ('https://docs.python.org/3', None),
    'sqlalchemy': ('https://docs.sqlalchemy.org/en/20/', None),
    'fastapi': ('https://fastapi.tiangolo.com/', None),
    'pydantic': ('https://docs.pydantic.dev/latest/', None),
}

templates_path = ['_templates']
exclude_patterns = ['_build', 'Thumbs.db', '.DS_Store']

language = 'de'

# -- Internationalization ----------------------------------------------------
locale_dirs = ['locales/']
gettext_compact = False

# -- Options for HTML output -------------------------------------------------
html_theme = 'sphinx_rtd_theme'

html_css_files = ['css/custom.css']

html_theme_options = {
    'logo_only': False,
    'prev_next_buttons_location': 'bottom',
    'style_external_links': True,
    'collapse_navigation': False,
    'sticky_navigation': True,
    'navigation_depth': 4,
    'includehidden': True,
    'titles_only': False,
}

html_static_path = ['_static']

# -- Versions switcher (RTD-style) -------------------------------------------
html_context = {
    'display_github': False,
    'current_version': release,
    'versions': [
        ('latest', '/'),
        (release, f'/{release}/de/'),
    ],
    'languages': [
        ('Deutsch', '/de/'),
        ('English', '/en/'),
    ],
}
