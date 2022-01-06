# SPDX-License-Identifier: GPL-3.0

# 1) Rename this file to config.ps1. Ensure it is in the same folder as oneup.ps1
# 2) Configure the options below to your liking
# 3) Run .\oneup.ps1

# Whether to do a dry run
# 1: Convert - Default
# 2: Convert (dry run)
$dryRun = 1

# Specify folder path that will contain your resulting Notes structure - Default: c:\temp\notes
$notesdestpath = 'c:\temp\notes'

# Specify a notebook name to convert
# '': Convert all notebooks - Default
# 'mynotebook': Convert specific notebook named 'mynotebook'
$targetNotebook = ''

# Whether to create new word .docx or reuse existing ones
# 1: Always create new .docx files - Default
# 2: Use existing .docx files (90% faster)
$usedocx = 2

# Whether to discard word .docx after conversion
# 1: Discard intermediate .docx files - Default
# 2: Keep .docx files
$keepdocx = 2

# Whether to use name .docx files using page ID with last modified date epoch, or hierarchy
# 1: Use page ID with last modified date epoch (recommended if you chose to use existing .docx files) - Default
# 2: Use hierarchy
$docxNamingConvention = 1

# Whether to use prefix vs subfolders
# 1: Create folders for subpages (e.g. Page\Subpage.<ext>) - Default
# 2: Add prefixes for subpages (e.g. Page_Subpage.<ext>)
$prefixFolders = 1

# Specify a value between 32 and 255 as the maximum length of markdown file names, and their folder names (only when using subfolders for subpages (e.g. Page\Subpage.<ext>)). File and folder names with length exceeding this value will be truncated accordingly.
# NOTE: If you are using prefixes for subpages (e.g. Page_Subpage.<ext>), it is recommended to set this to at 100 or more.
# Default: 32
$muFileNameAndFolderNameMaxLength = 255

# Whether to store media in single or multiple folders
# 1: Images stored in single 'media' folder at Notebook-level - Default
# 2: Separate 'media' folder for each folder in the hierarchy
$medialocation = 1

# Specify Pandoc output format and optional extensions in the format
#
#   <format><+extension><-extension>. 
#
# See: https://pandoc.org/MANUAL.html#options
#
# Examples:
#
#   org-simple_tables-multiline_tables-grid_tables+pipe_tables
#   markdown-simple_tables-multiline_tables-grid_tables+pipe_tables
#
#   commonmark+pipe_tables
#   gfm+pipe_tables
#   markdown_mmd-simple_tables-multiline_tables-grid_tables+pipe_tables
#   markdown_phpextra-simple_tables-multiline_tables-grid_tables+pipe_tables
#   markdown_strict+simple_tables-multiline_tables-grid_tables+pipe_tables
# Recommended:
#   <markup>-simple_tables-multiline_tables-grid_tables+pipe_tables
$conversion = 'org-simple_tables-multiline_tables-grid_tables+pipe_tables'

# Specify a custom Markup Pack to override default
$markupPack = 'none'

# Whether to include page timestamp and separator at top of document
# 1: Include - Default
# 2: Don't include
$headerTimestampEnabled = 1

# Whether to clear double spaces between bullets, non-breaking spaces from blank lines, and '>` after bullet lists
# 1: Clear double spaces in bullets - Default
# 2: Keep double spaces
$keepspaces = 1

# Whether to clear escape symbols from markup files. See: https://pandoc.org/MANUAL.html#backslash-escapes
# 1: Clear all '\' characters  - Default
# 2: Clear all '\' characters except those preceding alphanumeric characters
# 3: Keep '\' symbol escape
$keepescape = 1

# Whether to use Line Feed (LF) or Carriage Return + Line Feed (CRLF) for new lines
# 1: LF (unix) - Default
# 2: CRLF (windows)
$newlineCharacter = 1

# Whether to include a PDF export alongside the markdown file
# 1: Don't include PDF - Default
# 2: Include PDF
$exportPdf = 1
