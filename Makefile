.PHONY: get analyze test generate format publish publish-dry-run

get:
	dart pub get

analyze:
	tool/analyze.sh

test:
	tool/test.sh

generate:
	tool/generate.sh

format:
	dart format .

publish-dry-run:
	tool/publish.sh --dry-run

publish:
	tool/publish.sh
