tigerbrew: tigerbrew-brew/.git/config tigerbrew-core/.git/config

.PHONY: all
.DELETE_ON_ERROR:
.SECONDARY:

legacy-homebrew/.git/config:
	git clone https://github.com/Homebrew/legacy-homebrew.git

brew/.git/config:
	git clone https://github.com/Homebrew/brew.git

homebrew-core/.git/config:
	git clone https://github.com/Homebrew/homebrew-core.git

tigerbrew/.git/config:
	git clone https://github.com/mistydemeo/tigerbrew.git

%.tsv: %/.git/config
	(cd $* &&  \
		printf 'SHA1\tSubject\tAuthor_name\tAuthor_email\tAuthor_date\tCommitter_name\tCommitter_email\tCommitter_date\n'; \
		git log --pretty='%H%x09%s%x09%an%x09%ae%x09%at%x09%cn%x09%ce%x09%ct') >$@

%.html %.sh %.tsv: %.rmd
	Rscript -e 'rmarkdown::render("$<")'
	chmod +x $*.sh

brew-env-filter.sh: legacy-homebrew.tsv brew.tsv

core-env-filter.sh: legacy-homebrew.tsv homebrew-core.tsv

# Lift over commits that differ between Homebrew/legacy-homebrew and Homebrew/brew.
tigerbrew-brew/.git/config: tigerbrew/.git/config brew-env-filter.sh
	cp -a tigerbrew tigerbrew-brew
	cd tigerbrew-brew && git remote add legacy-homebrew https://github.com/Homebrew/legacy-homebrew.git
	cd tigerbrew-brew && git fetch legacy-homebrew
	cd tigerbrew-brew && git remote add brew https://github.com/Homebrew/brew.git
	cd tigerbrew-brew && git fetch brew
	# Change #123 to mistydemeo/tigerbrew#123.
	cd tigerbrew-brew && git filter-branch --msg-filter 'gsed -Ee "s~ (#[0-9]+)~ mistydemeo/tigerbrew\1~g"' -- legacy-homebrew/master..
	# Change #123 to Homebrew/homebrew#123.
	# Remove Library/Formula and Library/Aliases.
	# Correct committer author and date.
	cd tigerbrew-brew && git filter-branch -f --prune-empty \
		--msg-filter 'gsed -Ee "s~ (#[0-9]+)~ Homebrew/homebrew\1~g"' \
		--index-filter 'git rm --cached --ignore-unmatch -r -q -- Library/Formula Library/Aliases' \
		--env-filter ". $(PWD)/brew-env-filter.sh" \
		-- --all
	# Remove empty merge commits after 001b8de Merge branch 'qt5'.
	cd tigerbrew-brew && git filter-branch -f --prune-empty --parent-filter $(PWD)/independent-parents -- 001b8de679e776516ae266699e40d403945137d2..

# Lift over commits that differ between legacy-homebrew and homebrew-core.
# a9bfaf1 add formula_renames.json and tap_migrations.json
# 0f293a9 add LICENSE.txt
# 5199b51 mlton 20130715 (new formula)
# 26e0c51 update tap_migrations
# 1413b79 libodbc++: boneyard
# 71e2276 Merge remote-tracking branch 'origin/master'
# ef98654 imapsync: update 1.678 bottle.
# 2323ae2 update tap_migrations
tigerbrew-core/.git/config: tigerbrew/.git/config core-env-filter.sh
	cp -a tigerbrew tigerbrew-core
	cd tigerbrew-core && git remote add legacy-homebrew https://github.com/Homebrew/legacy-homebrew.git
	cd tigerbrew-core && git fetch legacy-homebrew
	cd tigerbrew-core && git remote add homebrew-core https://github.com/Homebrew/homebrew-core.git
	cd tigerbrew-core && git fetch homebrew-core
	# Change #123 to mistydemeo/tigerbrew#123.
	cd tigerbrew-core && git filter-branch -f --msg-filter 'gsed -Ee "s~ (#[0-9]+)~ mistydemeo/tigerbrew\1~g"' -- legacy-homebrew/master..master
	# Change #123 to Homebrew/homebrew#123.
	# Remove all files except Library/Formula and Library/Aliases.
	# Correct committer author and date.
	cd tigerbrew-core && git filter-branch -f --prune-empty \
		--msg-filter 'gsed -Ee "s~ (#[0-9]+)~ Homebrew/homebrew\1~g"' \
		--index-filter 'git rm --cached --ignore-unmatch -r -q -- . ; git reset -q $$GIT_COMMIT -- Library/Formula Library/Aliases;' \
		--env-filter ". $(PWD)/core-env-filter.sh" \
		-- --all
	# Reroot on Library.
	cd tigerbrew-core && git filter-branch -f --prune-empty --subdirectory-filter Library -- --all
	# Graft a9bfaf1 add formula_renames.json and tap_migrations.json
	# and 0f293a9 add LICENSE.txt
	# onto 47e3f93 libxslt: update 1.1.28_1 bottle.
	cd tigerbrew-core && git filter-branch -f --parent-filter 'gsed s/89170095faff1dfde1edcbc4b96bec671d6f8b2d/0f293a9b3d8904f50bc53fbc8154e224b8493bec/' -- --ancestry-path 89170095faff1dfde1edcbc4b96bec671d6f8b2d..
	# Add formula_renames.json from a9bfaf1 add formula_renames.json and tap_migrations.json
	# Add LICENSE.txt from 0f293a9 add LICENSE.txt
	cd tigerbrew-core && git filter-branch -f --tree-filter "git checkout 0f293a9 LICENSE.txt formula_renames.json" -- --ancestry-path 0f293a9b3d8904f50bc53fbc8154e224b8493bec..
	# Add formula_renames.json from a9bfaf1 add formula_renames.json and tap_migrations.json
	cd tigerbrew-core && git filter-branch -f --tree-filter "git checkout a9bfaf1 tap_migrations.json" -- --ancestry-path a9bfaf1504d66c6788daa3600befeb06f56289d4..
	# Several formula_rename updates originally came here; skipping
	# them because Tigerbrew is further behind in history.
