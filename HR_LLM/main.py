import gradio as gr
import re
import getpass
import os
from gpt_model import GPT
from models import *


OUTPUT_DIR = "interviews"
os.makedirs(OUTPUT_DIR, exist_ok=True)

os.environ["OPENAI_API_KEY"] = getpass.getpass("Введите OpenAI API Key:")

gpt = GPT("gpt-3.5-turbo")
blocks = gr.Blocks()

with blocks as demo:
    subject = gr.Dropdown([(elem["name"], index) for index, elem in enumerate(models)], label="Данные")
    name = gr.Label(show_label=False)
    prompt = gr.Textbox(label="Промт", interactive=True)
    link = gr.HTML()
    query = gr.Textbox(label="Запрос к LLM", interactive=True)

    def onchange(dropdown):
        return [
            models[dropdown]['name'],
            re.sub('\t+|\s\s+', ' ', models[dropdown]['prompt']),
            models[dropdown]['query'],
            f"<a target='_blank' href = '{models[dropdown]['doc']}'>Документ для обучения</a>"
        ]

    subject.change(onchange, inputs=[subject], outputs=[name, prompt, query, link])

    with gr.Row():
        train_btn = gr.Button("Обучить модель")
        request_btn = gr.Button("Запрос к модели")
        clear_btn = gr.Button("Очистить историю")
        save_btn = gr.Button("Сохранить в JSON")

    def train(dropdown):
        gpt.load_search_indexes(models[dropdown]['doc'])
        return gpt.log

    def predict(p, q):
        result = gpt.answer_index(p, q)
        return [result, gpt.log]

    def clear():
        return gpt.clear_history()

    def save():
        return gpt.save_history_to_json()

    with gr.Row():
        response = gr.Textbox(label="Ответ LLM")
        log = gr.Textbox(label="Логирование")

    train_btn.click(train, [subject], log)
    request_btn.click(predict, [prompt, query], [response, log])
    clear_btn.click(clear, inputs=[], outputs=log) # Добавлено для очистки истории
    save_btn.click(save, inputs=[], outputs=log) # Добавлено для сохранения истории


# Запуск
demo.launch()