import os
import argparse
from operator import add
import pyspark.pandas as pd
from pyspark.ml.feature import Imputer
from pyspark.sql import SparkSession


def process_data(spark):
    parser = argparse.ArgumentParser()
    parser.add_argument("--titanic_data")
    parser.add_argument("--wrangled_data")

    args = parser.parse_args()
    print("Arguments received: ")
    print(args.wrangled_data)
    print(args.titanic_data)

    # print(os.system("curl -v https://mlstorage10092.blob.core.windows.net"))

    
    ## Confirm what Spark sees for azureml:// paths
    jvm = spark._jvm
    uri = jvm.java.net.URI(args.titanic_data)
    scheme = uri.getScheme()
    print("Scheme:", scheme)
    conf = spark._jsc.hadoopConfiguration()
    fs = jvm.org.apache.hadoop.fs.FileSystem.get(uri, conf)
    print("Hadoop FS class:", fs.getClass().getName())

    # Read the data in spark session
    df = pd.read_csv(args.titanic_data, index_col="PassengerId")
    imputer = Imputer(inputCols=["Age"], outputCol="Age").setStrategy(
        "mean"
    )  # Replace missing values in Age column with the mean value
    df.fillna(
        value={"Cabin": "None"}, inplace=True
    )  # Fill Cabin column with value "None" if missing
    df.dropna(inplace=True)  # Drop the rows which still have any missing value

    print("dataframe is modified")

    df.to_csv(args.wrangled_data, index_col="PassengerId")

    print("dataframe is saved to output path")

def main():
    spark = SparkSession.builder.getOrCreate()
    ## NOTE: Spark level logging is enabled via `log4j2.properties` file in the current src folder.
    ## Control logging levels there as needed.
    process_data(spark)

if __name__ == "__main__":
    main()



