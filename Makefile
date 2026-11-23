.PHONY: check dist

# Тесты и сборка дистрибутива живут в dev/; здесь только удобные точки входа.
check:
	$(MAKE) -C dev check

dist:
	$(MAKE) -C dev dist
