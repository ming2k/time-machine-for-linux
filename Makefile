.PHONY: test clean install

install:
	chmod +x bin/*.sh
	chmod +x lib/**/*.sh
	chmod +x tests/**/*.sh

test:
	./tests/test_runner.sh

clean:
	find . -name "*.tmp" -delete
	find . -name "*~" -delete
	find . -name "*.swp" -delete
	find . -name "*.swo" -delete 