git add .gitmodules
git submodule deinit -f -- $1
rm -Rf .git/modules/$1
git rm -f $1
