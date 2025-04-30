import streamlit as st
import pandas as pd
import kagglehub
import os
from sklearn.preprocessing import StandardScaler
from sklearn.model_selection import train_test_split
from imblearn.over_sampling import SMOTE
import numpy as np

path = kagglehub.dataset_download("jacopoferretti/child-weight-at-birth-and-gestation-details")
csv_files = [f for f in os.listdir(path) if f.endswith('.csv')]
if not csv_files:
    raise FileNotFoundError("CSV-файл не найден в загруженной директории.")

csv_file_path = os.path.join(path, csv_files[0])

df = pd.read_csv(csv_file_path)
df.dropna(inplace=True)

# Обработка
df['bwt_grams'] = df['bwt'] * 28.35
def classify_weight(bwt_grams):
    if bwt_grams < 2500:
        return 0
    elif 2500 <= bwt_grams < 3000:
        return 1
    elif 3000 <= bwt_grams <= 4000:
        return 2
    else:
        return 3
df['weight_class'] = df['bwt_grams'].apply(classify_weight)

features = ['gestation', 'parity', 'age', 'height', 'weight', 'smoke']
X = df[features]
y = df['weight_class']

scaler = StandardScaler()
X_scaled = scaler.fit_transform(X)

# Балансировка
smote = SMOTE(random_state=42)
X_balanced, y_balanced = smote.fit_resample(X_scaled, y)

# Разделение
X_train, _, y_train, _ = train_test_split(
    X_balanced, y_balanced, test_size=0.2, random_state=42, stratify=y_balanced
)

# Сохранение
np.save("X_train.npy", X_train)
np.save("y_train.npy", y_train)