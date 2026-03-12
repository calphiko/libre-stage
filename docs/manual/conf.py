# Configuration file for the Sphinx documentation builder.
# https://www.sphinx-doc.org/en/master/usage/configuration.html

import json
import os

# -- Read version from version.json ------------------------------------------
_root = os.path.join(os.path.dirname(__file__), '..', '..')
with open(os.path.join(_root, 'version.json'), encoding='utf-8') as _f:
    _vdata = json.load(_f)

release = _vdata.get('release', 'v0.0.0')          # e.g. "v0.3.5"
version = '.'.join(release.lstrip('v').split('.')[:2])  # e.g. "0.3"

# -- Project information -----------------------------------------------------
project = 'libreStage'
author = 'libreStage contributors'
copyright = '2026, libreStage contributors'

# -- General configuration ---------------------------------------------------
extensions = [
    'sphinx_copybutton',
]

templates_path = ['_templates']
exclude_patterns = ['_build', 'Thumbs.db', '.DS_Store']

language = 'de'

# -- Internationalization ----------------------------------------------------
locale_dirs = ['locales/']
gettext_compact = False

# -- Options for HTML output -------------------------------------------------
html_theme = 'sphinx_rtd_theme'

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


