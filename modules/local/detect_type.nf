process DETECT_TYPE {

  //publishDir "${params.outdir}/pattern", mode: 'copy', pattern: '*pattern.txt'

  input:
  path pattern_search_jar
  path bamFile
  path lpaRegion

  output:
  path "${bamFile.baseName}-pattern.txt", emit: detected_pattern
  tuple file("${bamFile.baseName}.extracted.bam"), path("${bamFile.baseName}.bed"), emit: bam_bed_ch
  """
  samtools view -h -L ${lpaRegion} ${bamFile} -o ${bamFile.baseName}.extracted.bam
  bedtools bamtofastq -i ${bamFile.baseName}.extracted.bam -fq ${bamFile.baseName}.fastq
  java -jar ${pattern_search_jar} ${bamFile.baseName}.fastq --output ${bamFile.baseName}-pattern.txt --output-bed ${bamFile.baseName}.bed --pattern CCACTGTCACTGGAA,TTCCAGTGACAGTGG --build ${params.build}
"""

}
