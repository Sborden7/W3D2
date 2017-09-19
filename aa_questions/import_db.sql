CREATE TABLE users (
  id INTEGER PRIMARY KEY,
  fname VARCHAR(255) NOT NULL,
  lname VARCHAR(255) NOT NULL
);

CREATE TABLE questions (
  id INTEGER PRIMARY KEY,
  title VARCHAR(255) NOT NULL,
  body TEXT NOT NULL,
  author_id INTEGER NOT NULL,

  FOREIGN KEY (author_id) REFERENCES users(id)
);

CREATE TABLE question_follows (
  id INTEGER PRIMARY KEY,
  user_id INTEGER NOT NULL,
  question_id INTEGER NOT NULL,

  FOREIGN KEY (user_id) REFERENCES users(id),
  FOREIGN KEY (question_id) REFERENCES questions(id)
);

CREATE TABLE replies (
  id INTEGER PRIMARY KEY,
  subject_id INTEGER NOT NULL,
  parent_reply_id INTEGER,
  user_id INTEGER NOT NULL,
  body TEXT NOT NULL,

  FOREIGN KEY (subject_id) REFERENCES questions(id),
  FOREIGN KEY (parent_reply_id) REFERENCES replies(id),
  FOREIGN KEY (user_id) REFERENCES users(id)
);

CREATE TABLE question_likes (
  id INTEGER PRIMARY KEY,
  user_id INTEGER NOT NULL,
  question_id INTEGER NOT NULL,

  FOREIGN KEY (user_id) REFERENCES users(id),
  FOREIGN KEY (question_id) REFERENCES questions(id)
);

INSERT INTO
  users (fname, lname)
VALUES
  ('Seth', 'Borden'),
  ('Ethan', 'Schneider');

INSERT INTO
  questions (title, body, author_id)
VALUES
  ('Tequila?', 'Can we have tequila at happy hours?', 1),
  ('How?', 'How do?', 2),
  ('What?', 'What is in the hallway behind the bathroom?', 1),
  ('Mangos', 'Why do we not have mangoes?', 2),
  ('Recycling', 'Can we have recycling in the kitchen?', 2);

INSERT INTO
  replies (subject_id, parent_reply_id, user_id, body)
VALUES
  (1, NULL, 2, 'Very inappropriate'),
  (2, NULL, 1, 'IDK'),
  (1, 1, 1, 'But it is so much fun'),
  (1, 3, 2, 'Yer fun');

INSERT INTO
  question_follows (user_id, question_id)
VALUES
  (2, 2),
  (1, 2),
  (1, 1);

INSERT INTO
  question_likes (user_id, question_id)
VALUES
  (1, 2),
  (2, 2),
  (1, 1),
  (2, 4);
