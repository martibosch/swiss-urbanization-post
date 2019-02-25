swiss-urbanization-post
=======================

Materials to reproduce the blog post of http://martibosch.github.io/managing-analysis-workflows-geodata-make/

Prerequisites: a Python distribution with conda

Instructions to reproduce (commands executed from the root directory of this repository):

1. Create the conda environment by executing `make create_environment`

2. Activate the environment by executing `conda activate swiss-urbanization-post`

3. Update the `src/data/download_clc.py` script so that it downloads the [CORINE Land Cover](https://land.copernicus.eu/pan-european/corine-land-cover) datasets for the years 2000, 2006 and 2012 (the datasets are open but require registration) to the `data/raw/clc` directory, **or** contact me in order to get a temporary access keys to a S3 service that will provide you such files without need to change the code.

4. Generate the figure to `reports/figures/swiss-urbanization.png` by executing `make figure`

See the [overview](https://github.com/martibosch/swiss-urbanization-post/blob/master/notebooks/overview.ipynb) notebook for a more visual description of the workflow.

---

<p><small>Project based on the <a target="_blank" href="https://drivendata.github.io/cookiecutter-data-science/">cookiecutter data science project template</a>. #cookiecutterdatascience</small></p>
