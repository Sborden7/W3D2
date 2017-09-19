require 'sqlite3'
require 'singleton'

class QuestionsDatabase < SQLite3::Database
  include Singleton

  def initialize
    super('questions.db')
    self.type_translation = true
    self.results_as_hash = true
  end
end

class User
  attr_accessor :fname, :lname

  def self.all
    users = QuestionsDatabase.instance.execute('SELECT * FROM users')
    users.map { |user| User.new(user) }
  end

  def self.find_by_id(id)
    data = QuestionsDatabase.instance.execute(<<-SQL, id)
      SELECT
        *
      FROM
        users
      WHERE
        id = ?
    SQL

    User.new(data.first)
  end

  def self.find_by_name(fname, lname)
    users = QuestionsDatabase.instance.execute(<<-SQL, fname, lname)
      SELECT
        *
      FROM
        users
      WHERE
        fname = ? AND lname = ?
    SQL

    users_by_name = users.map{|user| User.new(user)}
    return users_by_name.first if users_by_name.count == 1
    users_by_name
  end

  def initialize(options)
    @id = options['id']
    @fname = options['fname']
    @lname = options['lname']
  end

  def save
    if @id
      QuestionsDatabase.instance.execute(<<-SQL, @fname, @lname, @id)
        UPDATE
          users
        SET
          fname = ?, lname = ?
        WHERE
          id = ?
      SQL
    else
      QuestionsDatabase.instance.execute(<<-SQL, @fname, @lname)
        INSERT INTO
          users (fname, lname)
        VALUES
          (?, ?)
      SQL
      @id = QuestionsDatabase.instance.last_insert_row_id
    end
  end

  def liked_questions
    QuestionLike.liked_questions_for_user_id(@id)
  end

  def authored_questions
    Question.find_by_author_id(@id)
  end

  def authored_replies
    Reply.find_by_user_id(@id)
  end

  def followed_questions
    QuestionFollow.followed_questions_for_user_id(@id)
  end

  def average_karma
    karma_store = QuestionsDatabase.instance.execute(<<-SQL, @id)
      SELECT
        -- COUNT(DISTINCT(questions.id))
        ((COUNT(question_likes.question_id)) / (CAST(COUNT(DISTINCT(questions.id)) AS FLOAT))) AS average_karma
      FROM
        questions
      LEFT OUTER JOIN
        question_likes ON questions.id = question_likes.question_id
      WHERE
        questions.author_id = 1
      GROUP BY
        questions.author_id
    SQL

    karma_store.first
  end
end

class Question

  attr_accessor :title, :body, :author_id

  def self.all
    questions = QuestionsDatabase.instance.execute('SELECT * FROM questions')

    questions.map{|question| Question.new(question)}
  end

  def self.most_liked(n)
    QuestionLike.most_liked_questions(n)
  end

  def self.find_by_author_id(author_id)
    questions = QuestionsDatabase.instance.execute(<<-SQL, author_id)
      SELECT
        *
      FROM
        questions
      WHERE
        author_id = ?
    SQL

    questions.map { |question| Question.new(question) }
  end

  def self.find_by_keyword_in_title(keyword)
    questions = QuestionsDatabase.instance.execute(<<-SQL, key: "%#{keyword}%")
      SELECT
        *
      FROM
        questions
      WHERE
        title LIKE :key
    SQL

    questions.map { |question| Question.new(question) }
  end

  def self.find_by_id(id)
    data = QuestionsDatabase.instance.execute(<<-SQL, id)
      SELECT
        *
      FROM
        questions
      WHERE
        id = ?
    SQL

    Question.new(data.first)
  end

  def self.most_followed(n)
    QuestionFollow.most_followed_questions(n)
  end

  def initialize(options)
    @title = options['title']
    @body = options['body']
    @author_id = options['author_id']
    @id = options['id']
  end

  def save
    if @id
      QuestionsDatabase.instance.execute(<<-SQL, @title, @body, @author_id, @id)
        UPDATE
          questions
        SET
          title = ?, body = ?, author_id = ?
        WHERE
          id = ?
      SQL
    else
      QuestionsDatabase.instance.execute(<<-SQL, @title, @body, @author_id)
        INSERT INTO
          questions (title, body, author_id)
        VALUES
          (?, ?, ?)
      SQL
      @id = QuestionsDatabase.instance.last_insert_row_id
    end
  end

  def likers
    QuestionLike.likers_for_question_id(@id)
  end

  def num_likes
    QuestionLike.num_likes_for_question_id(@id)
  end

  def author
    User.find_by_id(@author_id)
  end

  def replies
    Reply.find_by_subject_id(@id)
  end

  def followers
    QuestionFollow.followers_for_question_id(@id)
  end
end

class QuestionFollow
  attr_accessor :user_id, :question_id

  def self.all
    question_follows = QuestionsDatabase.instance.execute("SELECT * FROM question_follows")
    question_follows.map { |follow| QuestionFollow.new(follow) }
  end

  def self.find_by_id(id)
    follow = QuestionsDatabase.instance.execute(<<-SQL, id)
      SELECT
        *
      FROM
        question_follows
      WHERE
        id = ?
    SQL

    QuestionFollow.new(follow.first)
  end

  def self.find_by_user_id(user_id)
    follows = QuestionsDatabase.instance.execute(<<-SQL, user_id)
      SELECT
        *
      FROM
        question_follows
      WHERE
        user_id = ?
    SQL

    follows.map { |follow| QuestionFollow.new(follow) }
  end

  def self.find_by_question_id(question_id)
    follows = QuestionsDatabase.instance.execute(<<-SQL, question_id)
      SELECT
        *
      FROM
        question_follows
      WHERE
        question_id = ?
    SQL

    follows.map { |follow| QuestionFollow.new(follow) }
  end

  def self.followers_for_question_id(question_id)
    users = QuestionsDatabase.instance.execute(<<-SQL, question_id)
      SELECT
        *
      FROM
        users
      JOIN
        question_follows ON users.id = question_follows.user_id
      WHERE
        question_id = ?
    SQL

    users.map { |user| User.new(user) }
  end

  def self.followed_questions_for_user_id(user_id)
    questions = QuestionsDatabase.instance.execute(<<-SQL, user_id)
      SELECT
        *
      FROM
        questions
      JOIN
        question_follows ON questions.id = question_follows.question_id
      WHERE
        question_follows.user_id = ?
    SQL

    questions.map { |question| Question.new(question)}
  end

  def self.most_followed_questions(n)
    questions = QuestionsDatabase.instance.execute(<<-SQL, n)
      SELECT
        title, COALESCE(COUNT(*), 0) AS follow_count
      FROM
        questions
      JOIN
        question_follows ON questions.id = question_follows.question_id
      GROUP BY
        question_follows.question_id
      ORDER BY
        follow_count DESC
      LIMIT
        ?
    SQL

    questions.map { |question| Question.new(question) }
  end

  def initialize(options)
    @id = options['id']
    @user_id = options['user_id']
    @question_id = options['question_id']
  end
end

class Reply
  attr_accessor :subject_id, :parent_reply_id, :user_id, :body

  def self.all
    replies = QuestionsDatabase.instance.execute('SELECT * FROM replies')
    replies.map {|reply| Reply.new(reply)}
  end

  def self.find_by_id(id)
    reply = QuestionsDatabase.instance.execute(<<-SQL, id)
      SELECT
        *
      FROM
        replies
      WHERE
        id = ?
    SQL

    Reply.new(reply.first)
  end

  def self.find_by_subject_id(subject_id)
    replies = QuestionsDatabase.instance.execute(<<-SQL, subject_id)
      SELECT
        *
      FROM
        replies
      WHERE
        subject_id = ?
    SQL

    replies.map {|reply| Reply.new(reply)}
  end

  def self.find_by_parent_reply_id(parent_reply_id)
    replies = QuestionsDatabase.instance.execute(<<-SQL, parent_reply_id)
      SELECT
        *
      FROM
        replies
      WHERE
        parent_reply_id = ?
    SQL

    replies.map {|reply| Reply.new(reply)}
  end

  def self.find_by_user_id(user_id)
    replies = QuestionsDatabase.instance.execute(<<-SQL, user_id)
      SELECT
        *
      FROM
        replies
      WHERE
        user_id = ?
    SQL

    replies.map {|reply| Reply.new(reply)}
  end

  def self.find_by_keyword_in_body(keyword)
    replies = QuestionsDatabase.instance.execute(<<-SQL, key: "%#{keyword}%")
      SELECT
        *
      FROM
        replies
      WHERE
        body LIKE :key
    SQL

    replies.map {|reply| Reply.new(reply)}
  end

  def initialize(options)
    @id = options['id']
    @subject_id = options['subject_id']
    @parent_reply_id = options['parent_reply_id']
    @user_id = options['user_id']
    @body = options['body']
  end

  def save
    if @id
      QuestionsDatabase.instance.execute(<<-SQL, @subject_id, @parent_reply_id, @user_id, @body, @id)
        UPDATE
          replies
        SET
          subject_id = ?, parent_reply_id = ?, user_id = ?, body = ?
        WHERE
          id = ?
      SQL
    else
      QuestionsDatabase.instance.execute(<<-SQL, @subject_id, @parent_reply_id, @user_id, @body)
        INSERT INTO
          replies (subject_id, parent_reply_id, user_id, body)
        VALUES
          (?, ?, ?, ?)
      SQL
      @id = QuestionsDatabase.instance.last_insert_row_id
    end
  end

  def author
    User.find_by_id(@user_id)
  end

  def question
    Question.find_by_id(@subject_id)
  end

  def parent_reply
    Reply.find_by_id(@parent_reply_id)
  end

  def child_replies
    Reply.find_by_parent_reply_id(@id)
  end

end

class QuestionLike
  attr_accessor :user_id, :question_id

  def self.all
    likes = QuestionsDatabase.instance.execute('SELECT * FROM question_likes')
    likes.map {|like| QuestionLike.new(like)}
  end

  def self.most_liked_questions(n)
    questions = QuestionsDatabase.instance.execute(<<-SQL, n)
      SELECT
        title, COUNT(*) AS like_count
      FROM
        questions
      JOIN
        question_likes ON questions.id = question_likes.question_id
      GROUP BY
        question_likes.question_id
      ORDER BY
        like_count DESC
      LIMIT
        ?
    SQL

    questions.map { |question| Question.new(question) }
  end

  def self.find_by_id(id)
    like = QuestionsDatabase.instance.execute(<<-SQL, id)
      SELECT
        *
      FROM
        question_likes
      WHERE
        id = ?
    SQL

    QuestionLike.new(like.first)
  end

  def self.liked_questions_for_user_id(user_id)
    likes = QuestionsDatabase.instance.execute(<<-SQL, user_id)
      SELECT
        *
      FROM
        question_likes
      WHERE
        user_id = ?
    SQL

    likes.map {|like| QuestionLike.new(like)}
  end

  def self.find_by_question_id(question_id)
    likes = QuestionsDatabase.instance.execute(<<-SQL, question_id)
      SELECT
        *
      FROM
        question_likes
      WHERE
        question_id = ?
    SQL

    likes.map {|like| QuestionLike.new(like)}
  end

  def self.likers_for_question_id(question_id)
    users = QuestionsDatabase.instance.execute(<<-SQL, question_id)
      SELECT
        *
      FROM
        users
      JOIN
        question_likes ON question_likes.user_id = users.id
      WHERE
        question_likes.question_id = ?
    SQL

    users.map { |user| User.new(user)}
  end

  def self.num_likes_for_question_id(question_id)
    num_likes = QuestionsDatabase.instance.execute(<<-SQL, question_id)
      SELECT
        COUNT(*) AS num_likes
      FROM
        question_likes
      WHERE
        question_id = ?
      GROUP BY
        question_id
    SQL

    num_likes.first['num_likes']
  end

  def initialize(options)
    @id = options['id']
    @user_id = options['user_id']
    @question_id = options['question_id']
  end
end
