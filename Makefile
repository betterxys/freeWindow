.PHONY: lint test check install doctor clean-golden

lint:
	luacheck modules init.lua spec

test:
	busted --helper=spec/helper.lua --output=utfTerminal spec/

check: lint test

install:
	bash scripts/install.sh

doctor:
	bash scripts/doctor.sh

# Re-bootstrap golden snapshots after an intentional behavior change.
clean-golden:
	rm -f spec/golden/*.lua
