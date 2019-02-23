.PHONY: clean download_gmb download_clc urban_extracts figure lint requirements sync_data_to_s3 sync_data_from_s3

#################################################################################
# GLOBALS                                                                       #
#################################################################################

PROJECT_DIR := $(shell dirname $(realpath $(lastword $(MAKEFILE_LIST))))
BUCKET = [OPTIONAL] your-bucket-for-syncing-data (do not include 's3://')
PROFILE = default
PROJECT_NAME = swiss-urbanization-post
PYTHON_INTERPRETER = python
VIRTUALENV = conda

#################################################################################
# COMMANDS                                                                      #
#################################################################################

## Install Python Dependencies
requirements: test_environment
ifeq (conda, $(VIRTUALENV))
	conda env update --name $(PROJECT_NAME) -f environment.yml
else
	$(PYTHON_INTERPRETER) -m pip install -U pip setuptools wheel
	$(PYTHON_INTERPRETER) -m pip install -r requirements.txt
endif

## Download data
# variables
DOWNLOAD_GMB_PY = src/data/download_gmb.py
DOWNLOAD_CLC_PY = src/data/download_clc.py

GMB_DIR = data/raw/gmb
GMB_SHP_BASENAME = g1a18
GMB_SHP_FILEPATH := $(GMB_DIR)/$(GMB_SHP_BASENAME).shp

CLC_DIR = data/raw/clc
CLC_BASENAMES = g100_clc00_V18_5 g100_clc06_V18_5 g100_clc12_V18_5
CLC_TIF_FILEPATHS := $(addsuffix .tif, \
	$(addprefix $(CLC_DIR)/, $(CLC_BASENAMES)))

# rules
$(GMB_DIR):
	mkdir $(GMB_DIR)
$(GMB_DIR)/%.zip: $(DOWNLOAD_GMB_PY) | $(GMB_DIR)
	$(PYTHON_INTERPRETER) $(DOWNLOAD_GMB_PY) $@
$(GMB_DIR)/%.shp: $(GMB_DIR)/%.zip
	unzip -j $< 'ggg_2018-LV95/shp/$(GMB_SHP_BASENAME)*' -d $(GMB_DIR)
	touch $(GMB_SHP_FILEPATH)

$(CLC_DIR):
	mkdir $(CLC_DIR)
$(CLC_DIR)/%.zip: $(DOWNLOAD_CLC_PY) | $(CLC_DIR)
	$(PYTHON_INTERPRETER) $(DOWNLOAD_CLC_PY) $(basename $(notdir $@)) $(basename $@).zip
$(CLC_DIR)/%.tif $(CLC_DIR)/%.aux: $(CLC_DIR)/%.zip
	unzip $< '$(basename $(notdir $@)).*' -d $(CLC_DIR)
	touch $@

download_gmb: $(GMB_SHP_FILEPATH)
download_clc: $(CLC_TIF_FILEPATHS)


## Urban extracts
# variables
MAKE_URBAN_EXTRACT_PY = src/data/make_urban_extract.py
URBAN_EXTRACTS_DIR = data/processed/urban_extracts
AGGLOMERATION_SLUGS = basel geneve zurich
URBAN_EXTRACTS_TIF_FILEPATHS := $(addprefix $(URBAN_EXTRACTS_DIR)/, $(foreach CLC_BASENAME, $(CLC_BASENAMES), $(foreach AGGLOMERATION_SLUG, $(AGGLOMERATION_SLUGS), $(AGGLOMERATION_SLUG)-$(CLC_BASENAME).tif)))

# rules
$(URBAN_EXTRACTS_DIR):
	mkdir $(URBAN_EXTRACTS_DIR)

# option 1: metaprogramming: generate rules on the fly
define MAKE_URBAN_EXTRACT
$(URBAN_EXTRACTS_DIR)/$(AGGLOMERATION_SLUG)-%.tif: $(CLC_DIR)/%.tif $(GMB_SHP_FILEPATH) | $(URBAN_EXTRACTS_DIR)
	$(PYTHON_INTERPRETER) $(MAKE_URBAN_EXTRACT_PY) $(GMB_SHP_FILEPATH) $(AGGLOMERATION_SLUG) $$< $$@
endef

$(foreach AGGLOMERATION_SLUG, $(AGGLOMERATION_SLUGS), $(eval $(MAKE_URBAN_EXTRACT)))

# option 2: second expansion
# .SECONDEXPANSION:
# $(URBAN_EXTRACTS_DIR)/%.tif: $(CLC_DIR)/$$(word 2, $$(subst -, , $$(notdir $$*))).tif $(MAKE_URBAN_EXTRACT_PY) $(GMB_SHP_FILEPATH) | $(URBAN_EXTRACTS_DIR)
# 	$(eval AGGLOMERATION_CLC := $(subst -, , $(notdir $@)))
# 	echo $(PYTHON_INTERPRETER) $(MAKE_URBAN_EXTRACT_PY) $(GMB_SHP_FILEPATH) $< $(word 1, $(AGGLOMERATION_CLC)) $(word 2, $(AGGLOMERATION_CLC))

urban_extracts: $(URBAN_EXTRACTS_TIF_FILEPATHS)

## Figure
# variables
MAKE_FIGURE_PY = src/visualization/make_figure.py
FIGURE_FILEPATH = reports/figures/swiss-urbanization.png
METRICS = proportion_of_landscape fractal_dimension_am

# rules
$(FIGURE_FILEPATH): $(MAKE_FIGURE_PY) $(URBAN_EXTRACTS_TIF_FILEPATHS)
	$(PYTHON_INTERPRETER) $(MAKE_FIGURE_PY) $(URBAN_EXTRACTS_DIR) $(FIGURE_FILEPATH) --metrics $(METRICS) --clc-basenames $(CLC_BASENAMES) --agglomeration-slugs $(AGGLOMERATION_SLUGS)
figure: $(FIGURE_FILEPATH)


## Clean rules
clean:
	find . -type f -name "*.py[co]" -delete
	find . -type d -name "__pycache__" -delete

## Lint using flake8
lint:
	flake8 src

## Upload Data to S3
sync_data_to_s3:
ifeq (default,$(PROFILE))
	aws s3 sync data/ s3://$(BUCKET)/data/
else
	aws s3 sync data/ s3://$(BUCKET)/data/ --profile $(PROFILE)
endif

## Download Data from S3
sync_data_from_s3:
ifeq (default,$(PROFILE))
	aws s3 sync s3://$(BUCKET)/data/ data/
else
	aws s3 sync s3://$(BUCKET)/data/ data/ --profile $(PROFILE)
endif

## Set up python interpreter environment
create_environment:
ifeq (conda,$(VIRTUALENV))
		@echo ">>> Detected conda, creating conda environment."
	conda env create --name $(PROJECT_NAME) -f environment.yml
		@echo ">>> New conda env created. Activate with:\nsource activate $(PROJECT_NAME)"
else
	$(PYTHON_INTERPRETER) -m pip install -q virtualenv virtualenvwrapper
	@echo ">>> Installing virtualenvwrapper if not already intalled.\nMake sure the following lines are in shell startup file\n\
	export WORKON_HOME=$$HOME/.virtualenvs\nexport PROJECT_HOME=$$HOME/Devel\nsource /usr/local/bin/virtualenvwrapper.sh\n"
	@bash -c "source `which virtualenvwrapper.sh`;mkvirtualenv $(PROJECT_NAME) --python=$(PYTHON_INTERPRETER)"
	@echo ">>> New virtualenv created. Activate with:\nworkon $(PROJECT_NAME)"
endif

## Test python environment is setup correctly
test_environment:
ifeq (conda,$(VIRTUALENV))
ifneq (${CONDA_DEFAULT_ENV}, $(PROJECT_NAME))
	$(error Must activate `$(PROJECT_NAME)` environment before proceeding)
endif
endif
	$(PYTHON_INTERPRETER) test_environment.py

#################################################################################
# PROJECT RULES                                                                 #
#################################################################################



#################################################################################
# Self Documenting Commands                                                     #
#################################################################################

.DEFAULT_GOAL := help

# Inspired by <http://marmelab.com/blog/2016/02/29/auto-documented-makefile.html>
# sed script explained:
# /^##/:
# 	* save line in hold space
# 	* purge line
# 	* Loop:
# 		* append newline + line to hold space
# 		* go to next line
# 		* if line starts with doc comment, strip comment character off and loop
# 	* remove target prerequisites
# 	* append hold space (+ newline) to line
# 	* replace newline plus comments by `---`
# 	* print line
# Separate expressions are necessary because labels cannot be delimited by
# semicolon; see <http://stackoverflow.com/a/11799865/1968>
.PHONY: help
help:
	@echo "$$(tput bold)Available rules:$$(tput sgr0)"
	@echo
	@sed -n -e "/^## / { \
		h; \
		s/.*//; \
		:doc" \
		-e "H; \
		n; \
		s/^## //; \
		t doc" \
		-e "s/:.*//; \
		G; \
		s/\\n## /---/; \
		s/\\n/ /g; \
		p; \
	}" ${MAKEFILE_LIST} \
	| LC_ALL='C' sort --ignore-case \
	| awk -F '---' \
		-v ncol=$$(tput cols) \
		-v indent=19 \
		-v col_on="$$(tput setaf 6)" \
		-v col_off="$$(tput sgr0)" \
	'{ \
		printf "%s%*s%s ", col_on, -indent, $$1, col_off; \
		n = split($$2, words, " "); \
		line_length = ncol - indent; \
		for (i = 1; i <= n; i++) { \
			line_length -= length(words[i]) + 1; \
			if (line_length <= 0) { \
				line_length = ncol - indent - length(words[i]) - 1; \
				printf "\n%*s ", -indent, " "; \
			} \
			printf "%s ", words[i]; \
		} \
		printf "\n"; \
	}' \
	| more $(shell test $(shell uname) = Darwin && echo '--no-init --raw-control-chars')
