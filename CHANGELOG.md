# Changelog

## 0.1.2

- Windows: add a portable .zip (no installer), bundle the Visual C++ runtime DLLs, and publish SHA256SUMS.txt.

## 0.1.1

- Fix: conversion failed on a fresh install ("Creation of temporary directory failed").
- Better DOCX -> MD -> DOCX fidelity: complex tables (merged cells, multi-paragraph cells) are
  now written as grid tables instead of HTML, so they come back as Word tables.
- Table-of-contents links, empty emphasis and image figures no longer break the round trip.

## 0.1.0

- First release: DOCX → Markdown and Markdown → DOCX with a bundled Pandoc.
- Markdown uses pandoc's Markdown flavor so a DOCX → MD → DOCX round trip keeps
  headings, lists, tables (with alignment), links, footnotes and images.
