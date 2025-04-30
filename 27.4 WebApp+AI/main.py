import streamlit as st
import numpy as np
from sklearn.preprocessing import StandardScaler
from xgboost import XGBClassifier
from sklearn.metrics import classification_report, confusion_matrix
import seaborn as sns
import matplotlib.pyplot as plt
import pandas as pd
from imblearn.over_sampling import SMOTE
from sklearn.model_selection import train_test_split


# Настройки страницы
st.set_page_config(page_title="Обучение и инференс модели", layout="centered")
st.title("🤖 Модель классификации веса новорождённого")

# Гиперпараметры
st.sidebar.header("🔧 Гиперпараметры модели")
max_depth = st.sidebar.slider("Макс. глубина дерева", 2, 10, 5)
learning_rate = st.sidebar.slider("Скорость обучения", 0.01, 0.5, 0.1)
reg_lambda = st.sidebar.slider("L2-регуляризация (lambda)", 0.0, 10.0, 1.0)
alpha = st.sidebar.slider("L1-регуляризация (alpha)", 0.0, 10.0, 0.0)

# Функция классификации веса
def classify_weight(bwt_grams):
    if bwt_grams < 2500:
        return 0
    elif 2500 <= bwt_grams < 3000:
        return 1
    elif 3000 <= bwt_grams <= 4000:
        return 2
    else:
        return 3

class_labels = {
    0: "Низкий (<2500 г)",
    1: "Пониженный (2500–2999 г)",
    2: "Нормальный (3000–4000 г)",
    3: "Избыточный (>4000 г)"
}

# === 1. Загрузка CSV для обучения ===
st.header("📁 Загрузка данных для обучения модели")
uploaded_train = st.file_uploader("Загрузите обучающий CSV-файл (с колонками: bwt, gestation, parity, age, height, weight, smoke)", type="csv")

model = None  # создадим глобально, чтобы использовать после обучения

if uploaded_train:
    df = pd.read_csv(uploaded_train)
    required_cols = ['bwt', 'gestation', 'parity', 'age', 'height', 'weight', 'smoke']
    if not all(col in df.columns for col in required_cols):
        st.error(f"❌ Ошибка: требуется наличие колонок: {', '.join(required_cols)}")
    else:
        st.success("✅ Файл успешно загружен!")

        df.dropna(inplace=True)
        df['bwt_grams'] = df['bwt'] * 28.35
        df['weight_class'] = df['bwt_grams'].apply(classify_weight)

        features = ['gestation', 'parity', 'age', 'height', 'weight', 'smoke']
        X = df[features]
        y = df['weight_class']

        # Стандартизация
        scaler = StandardScaler()
        X_scaled = scaler.fit_transform(X)

        # Балансировка
        smote = SMOTE(random_state=42)
        X_balanced, y_balanced = smote.fit_resample(X_scaled, y)

        # Разделение на train/test
        X_train, X_test, y_train, y_test = train_test_split(
            X_balanced, y_balanced, test_size=0.2, random_state=42, stratify=y_balanced
        )

        # Обучение модели
        model = XGBClassifier(
            objective='multi:softmax',
            num_class=4,
            eval_metric='mlogloss',
            max_depth=max_depth,
            learning_rate=learning_rate,
            reg_lambda=reg_lambda,
            alpha=alpha
        )
        model.fit(X_train, y_train)
        st.success("✅ Модель успешно обучена!")

        # Метрики
        y_pred = model.predict(X_test)
        st.subheader("📊 Классификационный отчёт")
        st.text(classification_report(y_test, y_pred, target_names=class_labels.values()))

        st.subheader("📉 Матрица ошибок")
        cm = confusion_matrix(y_test, y_pred)
        fig, ax = plt.subplots()
        sns.heatmap(cm, annot=True, fmt="d", cmap="Blues", xticklabels=class_labels.values(), yticklabels=class_labels.values())
        ax.set_xlabel("Предсказано")
        ax.set_ylabel("Истинно")
        st.pyplot(fig)

# === 2. Инференс на новых данных ===
st.header("🔍 Инференс на новых данных")
uploaded_infer = st.file_uploader("Загрузите CSV-файл для инференса (gestation, parity, age, height, weight, smoke)", type="csv", key="infer")

if uploaded_infer:
    if model is None:
        st.warning("⚠️ Сначала обучите модель, загрузив обучающий набор данных выше.")
    else:
        df_new = pd.read_csv(uploaded_infer)
        required_infer_cols = ['gestation', 'parity', 'age', 'height', 'weight', 'smoke']

        if not all(col in df_new.columns for col in required_infer_cols):
            st.error(f"❌ Отсутствуют нужные колонки: {', '.join(required_infer_cols)}")
        else:
            st.success("✅ Данные для инференса загружены.")
            scaler = StandardScaler()
            X_new_scaled = scaler.fit_transform(df_new[required_infer_cols])
            y_new_pred = model.predict(X_new_scaled)

            df_new['Прогноз_веса'] = [class_labels[p] for p in y_new_pred]
            st.subheader("📄 Результаты предсказания:")
            st.dataframe(df_new)

            st.download_button(
                label="📥 Скачать с результатами",
                data=df_new.to_csv(index=False).encode('utf-8'),
                file_name="predictions.csv",
                mime="text/csv"
            )

            fig2, ax2 = plt.subplots()
            sns.countplot(x=df_new['Прогноз_веса'], ax=ax2)
            ax2.set_title("Распределение предсказанных классов")
            st.pyplot(fig2)
