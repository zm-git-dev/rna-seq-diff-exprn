#!/bin/sh

COMMON_VARS=$1
source $COMMON_VARS

# Need to convert bed file from location-based to just
# the name of the gene and its count
COUNTS_BED_TAB=bedtools_counts_name-count.txt

# Need to skip the last 5 lines of an htseq-counts file
# (hence the 'notail')
COUNTS_HTSEQ_TAB=htseq_counts_notail.txt

# Initialize tables with column names and first file
COL_NAMES="#ucsc_id,geneSymbol"
IN_FILES_HTSEQ=$UCSC_SYMBOL
IN_FILES_BED=$UCSC_SYMBOL

for ((i=0;i<=$END;++i)); do
    BAM_PREFIX=${BAM_PREFIX_ARRAY[$i]}
    ID=${ID_ARRAY[$i]}
    OUT_DIR=$BASE_OUT_DIR/$ID

    echo -n "making name-count (from bedtools coverage data)"
    echo "file for $OUT_DIR"

    THIS_COUNTS_BED=$OUT_DIR/$COUNTS_BED
    THIS_COUNTS_BED_TAB=$OUT_DIR/$COUNTS_TAB
    if [ ! -e $THIS_COUNTS_BED_TAB ]; then
	$SCRIPTS_DIR/make-bed-name-count.sh $THIS_COUNTS_BED \
	    $THIS_COUNTS_BED_TAB
    fi

    THIS_COUNTS_HTSEQ=$OUT_DIR/$COUNTS_HTSEQ
    THIS_COUNTS_HTSEQ_TAB=$OUT_DIR/$COUNTS_HTSEQ_TAB
    if [ ! -e $THIS_COUNTS_HTSEQ_TAB ]; then
    # Take everything except the last 5 lines
	head -n \
	    `wc -l $THIS_COUNTS_HTSEQ | awk '{ print $1-5 }'`\
	    $THIS_COUNTS_HTSEQ > $THIS_COUNTS_HTSEQ_TAB
    fi

    # Add the filenames to the comma-separated list of
    # gene counts files we'll be merging
    IN_FILES_BED=$IN_FILES_BED,$THIS_COUNTS_BED_TAB
    IN_FILES_HTSEQ=$IN_FILES_HTSEQ,$THIS_COUNTS_HTSEQ_TAB
    COL_NAMES=$COL_NAMES,$ID
done

if [ $NUM_GROUPS > 0 ]; then
# look at the second column of $COND to find the groups
# --> saved in $COMMON_VARS
    for GROUP in $GROUPS ; do
	GROUP_BASE_DIR=$BASE_OUT_DIR/groups

	if [ ! -d $GROUP_BASE_DIR ]; then
	    mkdir -r $GROUP_BASE_DIR
	fi

	echo "making results/expression tab files for" $GROUP
	for ((i=1;i<=$NUM_GROUPS;++i)); do
	    THIS_GROUP_DIR=$GROUP_BASE_DIR/$GROUP$i
	    if [ ! -d $THIS_GROUP_DIR ]; then
		mkdir -r $THIS_GROUP_DIR
	    fi
	    
	    THIS_COUNTS_BED=$THIS_GROUP_DIR/$COUNTS_BED
	    THIS_COUNTS_TAB=$THIS_GROUP_DIR/$COUNTS_TAB

	    if [ ! -e $THIS_COUNTS_TAB ]; then
		$SCRIPTS_DIR/make-bed-name-count.sh \
		    $THIS_COUNTS_BED \
		    $THIS_COUNTS_TAB
	    fi
	    IN_FILES_BED=$IN_FILES_BED,$THIS_COUNTS_TAB
	    COL_NAMES=$COL_NAMES,$GROUP$i

	    BAM=`ls $G_DIR/*.bam  | head -n 1`
	    
	    THIS_COUNTS_HTSEQ=$G_DIR/$COUNTS_HTSEQ
	    THIS_HTSEQ_TAB=$G_DIR/$HTSEQ_TAB
	    echo THIS_HTSEQ_TAB $THIS_HTSEQ_TAB
#      if [ ! -e $THIS_COUNTS_HTSEQ ]; then
	    REF_GFF=/home/obot/bed_and_gtf/hg19_ucsc-genes.gtf
	    REF_HTSEQ_PREFIX=$G_DIR/ref_htseq_counts
	    samtools view $BAM | sort -k 1,1 |
	    /usr/local/bin/htseq-count \
		--stranded=no - $REF_GFF \
		>$REF_HTSEQ_PREFIX.txt \
		2>$REF_HTSEQ_PREFIX.err
#      fi


#      if [ ! -e $THIS_HTSEQ_TAB ]; then
    # Take everything except the last 5 lines
	    head -n \
		`wc -l $THIS_COUNTS_HTSEQ | awk '{print $1-5}'` \
		$THIS_COUNTS_HTSEQ > $THIS_HTSEQ_TAB
#      fi
	    IN_FILES_HTSEQ=$IN_FILES_HTSEQ,$THIS_HTSEQ_TAB
	    DEXSEQ_OUT=$G_DIR/dexseq_counts.txt
	    if [ ! -e $DEXSEQ_OUT ]; then
		samtools view $BAM | \
		    dexseq_count.py --stranded=no \
		    $DEXSEQ_GFF - $DEXSEQ_OUT
	    fi
	    
	done
    done
done

BED_COUNTS_TABLE=$EXPR_DIR/counts_bedtools.tab
HTSEQ_COUNTS_TABLE=$EXPR_DIR/counts_htseq.tab

$SCRIPTS_DIR/merge-results/expression-counts.sh \
    $IN_FILES_BED \
    $COL_NAMES $BED_COUNTS_TABLE

$SCRIPTS_DIR/merge-results/expression-counts.sh \
    $IN_FILES_HTSEQ \
    $COL_NAMES $HTSEQ_COUNTS_TABLE