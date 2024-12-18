import aiosqlite

DB_NAME = 'quiz_bot.db'


async def create_tables():
    async with aiosqlite.connect(DB_NAME) as db:
        await db.execute('''CREATE TABLE IF NOT EXISTS quiz_state (user_id INTEGER PRIMARY KEY, question_index INTEGER)''')
        await db.execute('''CREATE TABLE IF NOT EXISTS quiz_results (user_id INTEGER, result BOOLEAN)''')
        await db.commit()


async def get_quiz_index(user_id):
    async with aiosqlite.connect(DB_NAME) as db:
        async with db.execute('SELECT question_index FROM quiz_state WHERE user_id = (?)', (user_id, )) as cursor:
            results = await cursor.fetchone()
            return results[0] if results is not None else 0


async def update_quiz_index(user_id, index):
    async with aiosqlite.connect(DB_NAME) as db:
        await db.execute('INSERT OR REPLACE INTO quiz_state (user_id, question_index) VALUES (?, ?)', (user_id, index))
        await db.commit()


async def record_result(user_id, passed):
    async with aiosqlite.connect(DB_NAME) as db:
        await db.execute('INSERT INTO quiz_results (user_id, result) VALUES (?, ?)', (user_id, passed))
        await db.commit()


async def show_statistics(user_id):
    async with aiosqlite.connect(DB_NAME) as db:
        async with db.execute('SELECT COUNT(*) AS total, SUM(result) AS passed FROM quiz_results WHERE user_id = ?', (user_id, )) as cursor:
            stats = await cursor.fetchone()
            total = stats[0]
            passed = stats[1]
            return f"Статистика:\nВсего квизов: {total}\nПройдено успешно: {passed}"