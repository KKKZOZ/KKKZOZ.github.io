# abort on errors


# build


# navigate into the build output directory


# if you are deploying to a custom domain
# echo 'www.example.com' > CNAME
git init

git add -A
git commit -m 'deploy'

# if you are deploying to https://<USERNAME>.github.io
git push -f git@github.com:kkkzoz/kkkzoz.github.io.git master

# if you are deploying to https://<USERNAME>.github.io/<REPO>
# git push -f git@github.com:<USERNAME>/<REPO>.git main:gh-pages

