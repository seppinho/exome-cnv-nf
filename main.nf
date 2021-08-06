params.project="exome-validation"
params.input="$baseDir/test-data/*.bam"
params.gold="$baseDir/reference-data/gold/gold.txt"
params.region="$baseDir/reference-data/peterReadExtract.hg38.camo.LPA.realign.sorted.bed"
params.reference="$baseDir/reference-data/kiv2.fasta"
params.contig="KIV2_6"
params.threads = (Runtime.runtime.availableProcessors() - 1)
params.output="output"

bam_files_ch = Channel.fromPath(params.input)
region_file_ch = file(params.region)
ref_fasta = file(params.reference)
gold_standard = file(params.gold)
contig = file(params.contig)

MutservePerformance = "$baseDir/bin/MutservePerformance.java"

process build_bwa_index {

    input:
    file ref_fasta

    output:
    file "*.{amb,ann,bwt,pac,sa}" into bwa_index

    """
    bwa index "${ref_fasta}"
    """
}

process extractReads {
  input:
	  file bamFile from bam_files_ch
		file regionFile from region_file_ch
  output:
	  file "*.extracted.bam" into extracted_ch
	"""
	samtools view -h -@ 15 -L ${regionFile} ${bamFile} | awk '\$5 < 10 || \$1 ~ "^@"' | samtools view -hb - | samtools sort -n -@ 15 -o ${bamFile.baseName}.extracted.bam -
	"""
}


process bamToFastq {
  input:
	  file bamFile from extracted_ch
  output:
	  tuple val("${bamFile.baseName}"), "*.r1.fastq", "*.r2.fastq" into fastq_ch
	"""
	 bedtools bamtofastq -i ${bamFile} -fq ${bamFile.baseName}.r1.fastq -fq2 ${bamFile.baseName}.r2.fastq
	"""
}

process realign {
  publishDir "${params.output}", mode: "copy"
  input:
	   tuple baseName, file(r1_fastq), file(r2_fastq) from fastq_ch
		 file ref_fasta
		 file "*" from bwa_index
  output:
	  file "*.kiv2.realigned.bam" into realigned_ch
	"""
	bwa mem -M ${ref_fasta} -R "@RG\\tID:LPA-exome-${baseName}\\tSM:${baseName}\\tPL:ILLUMINA" ${r1_fastq} ${r2_fastq} | samtools sort -@ 15 -o ${baseName}.kiv2.realigned.bam -

	"""
}


process callVariants {
  publishDir "${params.output}", mode: "copy"
  input:
	   file bamFile from realigned_ch.collect()
		 file ref_fasta
		 file contig
  output:
	  file "${params.project}.txt" into variants_ch
	"""
	mutserve call --output ${params.project}.vcf --reference ${ref_fasta} --contig-name ${contig} ${bamFile} --no-ansi
	"""
}


process calculatePerformance {

publishDir "$params.output", mode: 'copy'

  input:
  file mutserve_file from variants_ch
  file gold_standard

  output:
  file "*.txt" into mutserve_performance_ch

  """
  jbang ${MutservePerformance} --gold ${gold_standard} --output ${params.project}-performance.txt ${mutserve_file}
  """

}
