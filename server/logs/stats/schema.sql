DROP TABLE IF EXISTS Sessions;
CREATE TABLE Sessions(
	start TEXT NOT NULL,
	stop TEXT NOT NULL,
	usertype TEXT NOT NULL,
	id INTEGER NOT NULL,
	age INTEGER,
	branch TEXT NOT NULL,
	department TEXT NOT NULL,
	client TEXT NOT NULL,
	PRIMARY KEY(start, id));
