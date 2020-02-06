#!/bin/bash

# database logen details
DB_USER=
DB_PASSWORD=

set -eux

strip () {
    echo $1 | sed -e 's/^"//g' -e 's/"$//g'
}

make_template () {
    touch $1

    echo '## '$2 > $1
    echo >> $1
    echo_ $3 >> $1
}

make_page () {
    touch $1

    echo '## '$2 > $1
    echo >> $1
    echo_ $3 >> $1
    echo '---' >> $1
    echo_ $4 >> $1
}

echo_() {
    printf '%b ' "$@\n\c"
}


IFS=$'\t' # mysql outputs in tab separated values

rm -rf tmp && mkdir tmp

DIRS='tmp/dirs.txt'
touch $DIRS
mysql -B -u$DB_USER -p$DB_PASSWORD \
    black_box -e '\
    SELECT CONCAT(categories.slug, "/", chapters.slug) AS dirname
    FROM chapters 
    INNER JOIN categories 
    ON chapters.category_id = categories.id' > $DIRS

CATEGORIES='tmp/categories.txt'
touch $CATEGORIES
mysql -B -u$DB_USER -p$DB_PASSWORD \
    black_box -e '\
    SELECT
    CONCAT(categories.slug, "/.template") AS filename,
    categories.title AS title,
    categories.description AS description
    FROM categories' > $CATEGORIES

CHAPTERS='tmp/chapters.txt'
touch $CHAPTERS
mysql -B -u$DB_USER -p$DB_PASSWORD \
    black_box -e '\
    SELECT
    CONCAT(categories.slug, "/", chapters.slug, "/.template") AS filename,
    chapters.title AS title,
    chapters.description AS description
    FROM chapters
    INNER JOIN categories 
    ON chapters.category_id = categories.id' > $CHAPTERS
 
PAGES='tmp/pages.txt'
touch $PAGES
mysql -B -u$DB_USER -p$DB_PASSWORD \
    black_box -e '\
    SELECT
    CONCAT(categories.slug, "/", chapters.slug, "/", pages.slug, ".md") AS filename,
    pages.title AS title,
    pages.description AS description,
    content
    FROM pages
    INNER JOIN chapters
    ON pages.chapter_id = chapters.id
    INNER JOIN categories 
    ON chapters.category_id = categories.id
    WHERE pages.deleted_at IS NULL
    AND content <> ""' > $PAGES
 
# set up the directory structure
while read -r DIR
do
    mkdir -p dist/$DIR
done < $DIRS

# write template files
while read -r FILENAME TITLE DESCRIPTION
do
    DESCRIPTION="${DESCRIPTION:-' '}"
    make_template dist/$FILENAME $TITLE $DESCRIPTION
done < $CATEGORIES

while read -r FILENAME TITLE DESCRIPTION
do
    DESCRIPTION="${DESCRIPTION:-' '}"
    make_template dist/$FILENAME $TITLE $DESCRIPTION
done < $CHAPTERS

while read -r FILENAME TITLE DESCRIPTION CONTENT
do
    [ -z $CONTENT ] && CONTENT=$DESCRIPTION && DESRCIPTION='.'

    make_page dist/$FILENAME $TITLE $DESCRIPTION $CONTENT
done < $PAGES


