#!/bin/zsh
dir=$(dirname "$0")
test_repo="$dir/test-repo"

# create repo
[[ -e "$test_repo" ]] && rm -rf "$test_repo"
mkdir "$test_repo"
git -C "$test_repo" init
git -C "$test_repo" config user.name 'author'
git -C "$test_repo" config user.email 'author@example.com'
git -C "$test_repo" config commit.gpgsign false
echo '04_ignored_dir\n14_ignored\n' > "$test_repo/.gitignore"

# create files
mkdir "$test_repo/00_not_modified_dir"
touch "$test_repo/00_not_modified_dir/file"
mkdir "$test_repo/01_modified_dir"
touch "$test_repo/01_modified_dir/file"
mkdir "$test_repo/02_modified_dirty_dir"
touch "$test_repo/02_modified_dirty_dir/file"
mkdir "$test_repo/03_dirty_dir"
touch "$test_repo/03_dirty_dir/file"
mkdir "$test_repo/04_ignored_dir"
touch "$test_repo/04_ignored_dir/file"

touch "$test_repo/05_not_modified"
touch "$test_repo/06_modified"
touch "$test_repo/07_modified_dirty"
touch "$test_repo/08_dirty"
touch "$test_repo/09_added"
touch "$test_repo/10_added_dirty"
touch "$test_repo/11_renamed1"
touch "$test_repo/12_renamed_dirty1"
touch "$test_repo/13_untracked"
touch "$test_repo/14_ignored"

echo 'This is renamed1' >> "$test_repo/11_renamed1"
echo 'renamed_dirty1 is this file' >> "$test_repo/12_renamed_dirty1"

# add files for first commit
git -C "$test_repo" add '.gitignore'
git -C "$test_repo" add '00_not_modified_dir/file'
git -C "$test_repo" add '01_modified_dir/file'
git -C "$test_repo" add '02_modified_dirty_dir/file'
git -C "$test_repo" add '05_not_modified'
git -C "$test_repo" add '06_modified'
git -C "$test_repo" add '07_modified_dirty'
git -C "$test_repo" add '08_dirty'
git -C "$test_repo" add '11_renamed1'
git -C "$test_repo" add '12_renamed_dirty1'

git -C "$test_repo" commit -m 'commit'

# Make necessary file changes
echo '1' >> "$test_repo/01_modified_dir/file"
echo '1' >> "$test_repo/02_modified_dirty_dir/file"
echo '1' >> "$test_repo/06_modified"
echo '1' >> "$test_repo/07_modified_dirty"
echo '1' >> "$test_repo/08_dirty"
echo '1' >> "$test_repo/10_added_dirty"
echo '1' >> "$test_repo/12_renamed_dirty1"

mv "$test_repo/11_renamed1" "$test_repo/11_renamed"
mv "$test_repo/12_renamed_dirty1" "$test_repo/12_renamed_dirty"

git -C "$test_repo" add '01_modified_dir/file'
git -C "$test_repo" add '02_modified_dirty_dir/file'
git -C "$test_repo" add '06_modified'
git -C "$test_repo" add '07_modified_dirty'
git -C "$test_repo" add '09_added'
git -C "$test_repo" add '10_added_dirty'
git -C "$test_repo" add '11_renamed1'
git -C "$test_repo" add '11_renamed'
git -C "$test_repo" add '12_renamed_dirty1'
git -C "$test_repo" add '12_renamed_dirty'

echo '2' >> "$test_repo/02_modified_dirty_dir/file"
echo '2' >> "$test_repo/07_modified_dirty"
echo '2' >> "$test_repo/10_added_dirty"
echo '2' >> "$test_repo/12_renamed_dirty"

