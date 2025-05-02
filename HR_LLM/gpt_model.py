from langchain.docstore.document import Document
from langchain.embeddings.openai import OpenAIEmbeddings
from langchain.vectorstores import Chroma
from langchain.text_splitter import CharacterTextSplitter
import requests
from openai import OpenAI
import tiktoken
import json
import os
import re
from datetime import datetime
from main import OUTPUT_DIR


class GPT():
    def __init__(self, model="gpt-3.5-turbo"):
        self.log = ''
        self.model = model
        self.search_index = None
        self.history = []  # Хранилище диалога
        self.client = OpenAI(api_key=os.environ["OPENAI_API_KEY"])

    def load_search_indexes(self, url):
        match_ = re.search('/document/d/([a-zA-Z0-9-_]+)', url)
        if match_ is None:
            raise ValueError('Неверный Google Docs URL')
        doc_id = match_.group(1)
        response = requests.get(f'https://docs.google.com/document/d/{doc_id}/export?format=txt')
        response.raise_for_status()
        text = response.text
        return self.create_embedding(text)

    def num_tokens_from_string(self, string):
        encoding = tiktoken.encoding_for_model(self.model)
        return len(encoding.encode(string))

    def create_embedding(self, data):
        source_chunks = []
        splitter = CharacterTextSplitter(separator="\n", chunk_size=1024, chunk_overlap=0)
        for chunk in splitter.split_text(data):
            source_chunks.append(Document(page_content=chunk, metadata={}))

        count_token = self.num_tokens_from_string(' '.join([x.page_content for x in source_chunks]))
        self.log += f'Количество токенов в документе : {count_token}\n'
        self.search_index = Chroma.from_documents(source_chunks, OpenAIEmbeddings())
        self.log += f'Данные из документа загружены в векторную базу данных\n'
        return self.search_index

    def num_tokens_from_messages(self, messages, model):
        try:
            encoding = tiktoken.encoding_for_model(model)
        except KeyError:
            print("Предупреждение: модель не создана. Используйте cl100k_base кодировку.")
            encoding = tiktoken.get_encoding("cl100k_base")

        if model in {
            "gpt-3.5-turbo-0613", "gpt-3.5-turbo-16k-0613", "gpt-4-0314",
            "gpt-4-32k-0314", "gpt-4-0613", "gpt-4-32k-0613",
            "gpt-4o", "gpt-4o-2024-05-13"
        }:
            tokens_per_message = 3
            tokens_per_name = 1
        elif model == "gpt-3.5-turbo-0301":
            tokens_per_message = 4
            tokens_per_name = -1
        elif "gpt-3.5-turbo" in model:
            self.log += 'Внимание! gpt-3.5-turbo может обновиться. Используйте gpt-3.5-turbo-0613. \n'
            return self.num_tokens_from_messages(messages, model="gpt-3.5-turbo-0613")
        elif "gpt-4" in model:
            self.log += 'Внимание! gpt-4 может обновиться. Используйте gpt-4-0613. \n'
            return self.num_tokens_from_messages(messages, model="gpt-4-0613")
        else:
            raise NotImplementedError(f"num_tokens_from_messages() не реализован для модели {model}.")

        num_tokens = 0
        for message in messages:
            num_tokens += tokens_per_message
            for key, value in message.items():
                num_tokens += len(encoding.encode(value))
                if key == "name":
                    num_tokens += tokens_per_name
        num_tokens += 3
        return num_tokens

    def answer_index(self, system, topic, temp=1):
        if not self.search_index:
            self.log += 'Модель необходимо обучить! \n'
            return ''

        docs = self.search_index.similarity_search(topic, k=5)
        self.log += 'Выбираем документы по степени схожести с вопросом из векторной базы данных: \n'
        message_content = re.sub(r'\n{2}', ' ', '\n '.join([f'Отрывок документа №{i+1}:\n' + doc.page_content + '\\n' for i, doc in enumerate(docs)]))
        self.log += f'{message_content} \n'

        messages = [{"role": "system", "content": system + f"{message_content}"}] + self.history
        messages.append({"role": "user", "content": topic})

        self.log += f"\n\nТокенов использовано на вопрос по версии TikToken: {self.num_tokens_from_messages(messages, self.model)}\n"

        completion = self.client.chat.completions.create(
            model=self.model,
            messages=messages,
            temperature=temp
        )

        reply = completion.choices[0].message.content
        self.history.append({"role": "user", "content": topic})
        self.history.append({"role": "assistant", "content": reply})

        self.log += '\nСтатистика по токенам от языковой модели:\n'
        self.log += f'Токенов использовано всего (вопрос): {completion.usage.prompt_tokens} \n'
        self.log += f'Токенов использовано всего (вопрос-ответ): {completion.usage.total_tokens} \n'

        return reply

    def clear_history(self):
        self.history = []
        return "История диалога очищена."

    def save_history_to_json(self):
        filename = f"interview_{datetime.now().strftime('%Y%m%d_%H%M%S')}.json"
        path = os.path.join(OUTPUT_DIR, filename)
        with open(path, "w", encoding="utf-8") as f:
            json.dump(self.history, f, ensure_ascii=False, indent=2)
        return f"История сохранена в файл {path}"
