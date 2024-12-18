import aiosqlite
import asyncio
import logging
from aiogram import Bot, Dispatcher, types
from aiogram.filters.command import Command
from aiogram.utils.keyboard import InlineKeyboardBuilder, ReplyKeyboardBuilder
from aiogram import F
from database import create_tables, get_quiz_index, update_quiz_index, record_result, show_statistics
from quiz_data import quiz_data
from config import API_TOKEN

logging.basicConfig(level=logging.INFO)

bot = Bot(token=API_TOKEN)
dp = Dispatcher()


def generate_options_keyboard(answer_options, right_answer):
    builder = InlineKeyboardBuilder()
    for option in answer_options:
        builder.add(types.InlineKeyboardButton(
            text=option,
            callback_data="right_answer" if option == right_answer else "wrong_answer")
        )
    builder.adjust(1)
    return builder.as_markup()


@dp.callback_query(F.data == "right_answer")
async def right_answer(callback: types.CallbackQuery):
    current_question_index = await get_quiz_index(callback.from_user.id)
    correct_answer = quiz_data[current_question_index]['options'][quiz_data[current_question_index]['correct_option']]

    await callback.message.answer(f"Верно! Ваш ответ: {correct_answer}")
    await callback.bot.edit_message_reply_markup(chat_id=callback.from_user.id, message_id=callback.message.message_id,
                                                 reply_markup=None)

    await update_quiz_index(callback.from_user.id, current_question_index + 1)
    if current_question_index + 1 < len(quiz_data):
        await get_question(callback.message, callback.from_user.id)
    else:
        await record_result(callback.from_user.id, True)
        await callback.message.answer("Это был последний вопрос. Квиз завершен! Поздравляем!")
        await show_statistics(callback.from_user.id)


@dp.callback_query(F.data == "wrong_answer")
async def wrong_answer(callback: types.CallbackQuery):
    current_question_index = await get_quiz_index(callback.from_user.id)
    correct_answer = quiz_data[current_question_index]['options'][quiz_data[current_question_index]['correct_option']]

    await callback.message.answer(f"Неправильно. Правильный ответ: {correct_answer}")
    await callback.bot.edit_message_reply_markup(chat_id=callback.from_user.id, message_id=callback.message.message_id,
                                                 reply_markup=None)

    await update_quiz_index(callback.from_user.id, current_question_index + 1)
    if current_question_index + 1 < len(quiz_data):
        await get_question(callback.message, callback.from_user.id)
    else:
        await record_result(callback.from_user.id, False)
        await callback.message.answer("Это был последний вопрос. Квиз завершен!")
        await show_statistics(callback.from_user.id)


@dp.message(Command("start"))
async def cmd_start(message: types.Message):
    builder = ReplyKeyboardBuilder()
    builder.add(types.KeyboardButton(text="Начать игру"))
    await message.answer("Добро пожаловать в квиз!", reply_markup=builder.as_markup(resize_keyboard=True))


async def get_question(message, user_id):
    current_question_index = await get_quiz_index(user_id)
    opts = quiz_data[current_question_index]['options']
    kb = generate_options_keyboard(opts, opts[quiz_data[current_question_index]['correct_option']])
    await message.answer(f"{quiz_data[current_question_index]['question']}", reply_markup=kb)


async def new_quiz(message):
    user_id = message.from_user.id
    await update_quiz_index(user_id, 0)
    await get_question(message, user_id)


@dp.message(F.text == "Начать игру")
@dp.message(Command("quiz"))
async def cmd_quiz(message: types.Message):
    await message.answer("Давайте начнем квиз!")
    await new_quiz(message)


async def main():
    await create_tables()
    await dp.start_polling(bot)


if __name__ == "__main__":
    asyncio.run(main())