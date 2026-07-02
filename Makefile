parse.a: parse.o lazy.o
	ar -r parse.a parse.o lazy.o
parse.o: parse.s
	as -o parse.o parse.s
lazy.o: lazy.s
	as -o lazy.o lazy.s
