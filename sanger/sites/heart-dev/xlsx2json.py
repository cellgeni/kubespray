import os
import json
import pandas
import ntpath


OUTOUT_PATH = "./supplementary"


def main(xlsx_path):
    for f in os.listdir(xlsx_path):
        if os.path.isfile(os.path.join(xlsx_path, f)) and f[-4:] == "xlsx":
            filename = os.path.join(xlsx_path, f)
            xlsx_to_json(filename)


def xlsx_to_json(filename):
    print(f"Converting file: {ntpath.basename(filename)}")
    xlsx = pandas.ExcelFile(filename)
    for sheet_name in xlsx.sheet_names:
        print(f"\t- Sheet: {sheet_name}")
        df = xlsx.parse(sheet_name, convert_float=False)
        json_df = dataframe_to_json(df)
        json_df["file"] = ntpath.basename(filename)[:-5]
        json_df["title"] = sheet_name
        write_json(json_df)


def write_json(json_df):
    filename = json_df["file"].replace(" ", "_")
    title = json_df["title"].replace(" ", "_")
    output_filename = f"{OUTOUT_PATH}/{filename}_{title}.json"
    with open(output_filename, "w", encoding='utf8') as out_file:
        json.dump(json_df, out_file, ensure_ascii=False)


def dataframe_to_json(df):
    columns = list(df.columns)
    df.fillna("", inplace=True)
    rows = [data.values.tolist() for _, data in df.iterrows()]
    return {"columns": columns, "rows": rows}


if __name__ == "__main__":
    xlsx_path = "./xlsx"
    main(xlsx_path)
