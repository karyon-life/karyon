import fs from 'node:fs';
import path from 'node:path';

const docsDir = path.join(process.cwd(), 'src', 'content', 'docs');
const outputDir = path.join(process.cwd(), 'public');
const outputFile = path.join(outputDir, 'book.md');

function getBookFiles(dir) {
  let results = [];
  try {
    const entries = fs.readdirSync(dir, { withFileTypes: true });
    for (const entry of entries) {
      const fullPath = path.join(dir, entry.name);
      
      // At the root docs level, only process directories starting with part-
      if (dir === docsDir && (!entry.isDirectory() || !entry.name.startsWith('part-'))) {
        continue;
      }

      if (entry.isDirectory()) {
        results = results.concat(getBookFiles(fullPath));
      } else if (entry.isFile() && entry.name.endsWith('.md')) {
        results.push(fullPath);
      }
    }
  } catch (error) {
    console.error(`Error reading directory ${dir}:`, error);
  }

  // Sort logically (so 2-foo comes before 10-bar)
  return results.sort((a, b) => a.localeCompare(b, undefined, { numeric: true, sensitivity: 'base' }));
}

function stripFrontmatter(content) {
  const frontmatterRegex = /^---\r?\n[\s\S]*?\r?\n---\r?\n/;
  if (frontmatterRegex.test(content)) {
    return content.replace(frontmatterRegex, '').trim();
  }
  return content.trim();
}

function aggregate() {
  console.log('Aggregating KARYON Architecture Book markdown files...');
  
  if (!fs.existsSync(docsDir)) {
    console.error(`Docs directory not found at ${docsDir}`);
    process.exit(1);
  }

  const files = getBookFiles(docsDir);
  
  if (files.length === 0) {
    console.warn('No markdown files found in the book structure.');
    return;
  }

  // Initial title and formatting
  let aggregatedContent = '# KARYON: The Architecture of a Cellular Graph Intelligence\n\n';
  aggregatedContent += '> This document is auto-generated from the KARYON documentation source.\n\n';

  for (const file of files) {
    try {
      const rawContent = fs.readFileSync(file, 'utf-8');
      const content = stripFrontmatter(rawContent);
      
      // Add a visual separator between sections/chapters if needed, but headers usually suffice.
      // We will append it with a standard markdown horizontal rule.
      aggregatedContent += `\n---\n\n${content}\n\n`;
    } catch (error) {
      console.error(`Error processing file ${file}:`, error);
    }
  }

  // Ensure public directory exists
  if (!fs.existsSync(outputDir)) {
    fs.mkdirSync(outputDir, { recursive: true });
  }

  fs.writeFileSync(outputFile, aggregatedContent);
  console.log(`Successfully aggregated ${files.length} parts into ${outputFile}`);
}

aggregate();
