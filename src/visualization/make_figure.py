import logging
from os import path
from pathlib import Path

import click
import matplotlib.pyplot as plt
from dotenv import find_dotenv, load_dotenv

import pylandstats as pls


class OptionEatAll(click.Option):
    # Option that can take an unlimided number of arguments
    # Copied from Stephen Rauch's answer in stack overflow.
    # https://stackoverflow.com/questions/48391777/nargs-equivalent-for-options-in-click
    def __init__(self, *args, **kwargs):
        self.save_other_options = kwargs.pop('save_other_options', True)
        nargs = kwargs.pop('nargs', -1)
        assert nargs == -1, 'nargs, if set, must be -1 not {}'.format(nargs)
        super(OptionEatAll, self).__init__(*args, **kwargs)
        self._previous_parser_process = None
        self._eat_all_parser = None

    def add_to_parser(self, parser, ctx):
        def parser_process(value, state):
            # method to hook to the parser.process
            done = False
            value = [value]
            if self.save_other_options:
                # grab everything up to the next option
                while state.rargs and not done:
                    for prefix in self._eat_all_parser.prefixes:
                        if state.rargs[0].startswith(prefix):
                            done = True
                    if not done:
                        value.append(state.rargs.pop(0))
            else:
                # grab everything remaining
                value += state.rargs
                state.rargs[:] = []
            value = tuple(value)

            # call the actual process
            self._previous_parser_process(value, state)

        retval = super(OptionEatAll, self).add_to_parser(parser, ctx)
        for name in self.opts:
            our_parser = parser._long_opt.get(name) or parser._short_opt.get(
                name)
            if our_parser:
                self._eat_all_parser = our_parser
                self._previous_parser_process = our_parser.process
                our_parser.process = parser_process
                break
        return retval


@click.command()
@click.argument('urban_extracts_dir', type=click.Path(exists=True))
@click.argument('out_figure_filepath', type=click.Path())
@click.option('--metrics', required=True, cls=OptionEatAll)
@click.option('--clc-basenames', required=True, cls=OptionEatAll)
@click.option('--agglomeration-slugs', required=True, cls=OptionEatAll)
def main(urban_extracts_dir, out_figure_filepath, metrics, clc_basenames,
         agglomeration_slugs):
    logger = logging.getLogger(__name__)

    URBAN_CLASS_VAL = 1

    num_rows = len(agglomeration_slugs)
    num_cols = len(metrics)
    figwidth, figlength = plt.rcParams['figure.figsize']
    fig, axes = plt.subplots(
        num_rows,
        num_cols,
        sharex=True,
        figsize=(figwidth * num_cols, figlength * num_rows))

    # extract the year code from the CLC basename, e.g., `00` from
    # `g100_clc12_V18_5`
    dates = [clc_basename[8:10] for clc_basename in clc_basenames]

    for i, agglomeration_slug in enumerate(agglomeration_slugs):
        logger.info(f'computing landscape metrics for {agglomeration_slug}')
        sta = pls.SpatioTemporalAnalysis(
            [
                path.join(urban_extracts_dir,
                          f'{agglomeration_slug}-{clc_basename}.tif')
                for clc_basename in clc_basenames
            ],
            metrics=metrics,
            classes=[URBAN_CLASS_VAL],
            dates=dates)

        for j, metric in enumerate(metrics):
            sta.plot_metric(
                metric,
                class_val=URBAN_CLASS_VAL,
                ax=axes[i, j],
                metric_legend=False)

    for i, agglomeration_slug in enumerate(agglomeration_slugs):
        axes[i, 0].set_ylabel(agglomeration_slug.title())

    for j, metric in enumerate(metrics):
        axes[0, j].set_title(metric)

    logger.info(f'saving figure to {out_figure_filepath}')

    fig.savefig(out_figure_filepath)


if __name__ == '__main__':
    log_fmt = '%(asctime)s - %(name)s - %(levelname)s - %(message)s'
    logging.basicConfig(level=logging.INFO, format=log_fmt)

    # not used in this stub but often useful for finding various files
    project_dir = Path(__file__).resolve().parents[2]

    # find .env automagically by walking up directories until it's found, then
    # load up the .env entries as environment variables
    load_dotenv(find_dotenv())

    main()
