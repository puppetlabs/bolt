/*
 * This file is part of the DITA Open Toolkit project.
 *
 * Copyright 2006 IBM Corporation
 *
 * See the accompanying LICENSE file for applicable license.

 */
package org.dita.dost.writer;

import static org.dita.dost.util.Constants.*;

import java.io.File;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.OutputStream;
import java.util.ArrayList;
import java.util.List;
import javax.xml.stream.XMLOutputFactory;
import javax.xml.stream.XMLStreamException;
import javax.xml.stream.XMLStreamWriter;

import org.dita.dost.exception.DITAOTException;
import org.dita.dost.index.IndexTerm;
import org.dita.dost.index.IndexTermTarget;
import org.dita.dost.log.MessageUtils;

/**
 * This class extends AbstractWriter, used to output index term
 * into eclipse help index file.
 * 
 *  @author Sirois, Eric
 * 
 *  @version 1.0 2006-10-17
 */
public final class EclipseIndexWriter extends AbstractExtendDitaWriter {

    private String filepath = null;

    private String targetExt = FILE_EXTENSION_HTML;

    /**
     * Boolean to indicate when we are processing indexsee and child elements
     */
    private boolean inIndexsee = false;

    /** List of index terms used to search for see references. */
    private List<IndexTerm> termCloneList = null;

    /**
     * Set the file path for output.
     * 
     * @param filePath The file path to where the plugin are created.
     */
    public void setFilePath(final String filePath) {
        filepath = filePath;
    }

    /**
     * 
     * @return filePath The file path to the plugin.xml file
     */
    public String getFilePath(){
        return filepath;
    }

    @Override
    public void write(final File filename) throws DITAOTException {
        OutputStream out = null;
        XMLStreamWriter serializer = null;
        try {
            out = new FileOutputStream(filename);
            //boolean for processing indexsee the new markup (Eclipse 3.6 feature).
            boolean indexsee = false;

            //RFE 2987769 Eclipse index-see
            if (this.getPipelineHashIO() != null){
                indexsee = Boolean.valueOf(this.getPipelineHashIO().getAttribute("eclipse.indexsee"));
                targetExt = this.getPipelineHashIO().getAttribute(ANT_INVOKER_EXT_PARAM_TARGETEXT);
            }

            serializer = XMLOutputFactory.newInstance().createXMLStreamWriter(out, "UTF-8");

            serializer.writeStartDocument();
            serializer.writeStartElement("index");
            //Clone the list of indexterms so we can look for see references
            termCloneList = cloneIndextermList(termList);
            for (final IndexTerm term : termList) {
                outputIndexTerm(term, serializer, indexsee);
            }
            serializer.writeEndElement(); // index
            serializer.writeEndDocument();
        } catch (final RuntimeException e) {
            throw e;
        } catch (final Exception e) {
            throw new DITAOTException(e);
        } finally {
            if (serializer != null) {
                try {
                    serializer.close();
                } catch (final XMLStreamException e) {
                    logger.error(e.getMessage(), e) ;
                }
            }
            if (out != null) {
                try {
                    out.close();
                } catch (final IOException e) {
                    logger.error(e.getMessage(), e) ;
                }
            }
        }
    }

    /**
     * Output the given indexterm into the XML writer.
     * 
     * @param term term to serialize
     * @param serializer XML output to write to
     * @param indexsee is term a see term
     */
    private void outputIndexTerm(final IndexTerm term, final XMLStreamWriter serializer, final boolean indexsee) throws XMLStreamException {
        final List<IndexTerm> subTerms = term.getSubTerms();
        final int subTermNum = subTerms.size();
        outputIndexTermStartElement(term, serializer, indexsee);
        if (subTermNum > 0) {
            for (final IndexTerm subTerm : subTerms) {
                outputIndexTerm(subTerm, serializer, indexsee);
            }
        }
        outputIndexTermEndElement(term, serializer, indexsee);
    }

    /**
     * Replace the file extension.
     * @param aFileName file name to be replaced
     * @return replaced file name
     */
    private String replaceExtName(final String aFileName){
        final int index = aFileName.indexOf(SHARP);
        if (aFileName.startsWith(SHARP)){
            return aFileName;
        } else if (index != -1){
            final String fileName = aFileName.substring(0, index);
            final int fileExtIndex = fileName.lastIndexOf(DOT);
            return (fileExtIndex != -1)
                    ? fileName.substring(0, fileExtIndex) + targetExt + aFileName.substring(index)
                            : aFileName;
        } else {
            final int fileExtIndex = aFileName.lastIndexOf(DOT);
            return (fileExtIndex != -1)
                    ? (aFileName.substring(0, fileExtIndex) + targetExt)
                            : aFileName;
        }
    }

    /**
     * Get index file name.
     * @param outputFileRoot root path
     * @return index file name
     */
    @Override
    public String getIndexFileName(final String outputFileRoot) {
        final File indexDir = new File(outputFileRoot).getParentFile();
        setFilePath(indexDir.getAbsolutePath());
        return new File(indexDir, "index.xml").getAbsolutePath();
    }

    /*
     * Method for see references in Eclipse. This version does not have a
     * dependency on a specific Eclipse version.
     * 
     * @param term  The indexterm to be processed.
     * @param printWriter The Writer used for writing content to disk.
     */
    private void outputIndexEntry(final IndexTerm term, final XMLStreamWriter serializer) throws XMLStreamException {

        final List<IndexTermTarget> targets = term.getTargetList();

        boolean foundIndexTerm = false;
        boolean foundIndexsee = false;

        String indexSeeRefTerm = null;

        /*
         * Use the cloned List to find the index-see reference in the list. If
         * found use that target URI for the href value, otherwise return a
         * warning to the build. RFE 2987769 Eclipse index-see
         */
        final int termCloneNum = termCloneList.size();

        // Index-see and index-see-also terms should also generate links to its
        // target
        // Otherwise, the term won't be displayed in the index tab.
        if (!targets.isEmpty()) {
            for (final IndexTermTarget target : targets) {
                final String targetUri = target.getTargetURI();
                final String targetName = target.getTargetName();
                if (targetUri == null) {
                    serializer.writeStartElement("topic");
                    serializer.writeAttribute("title", target.getTargetName());
                    serializer.writeEndElement(); // topic
                } else if (targetName != null && targetName.trim().length() > 0) {
                    /*
                     * Check to see if the target Indexterm is a "see"
                     * reference.Added inIndexsee so we know that we are still
                     * processing contentfrom a referenced indexterm.
                     */
                    if (term.getTermPrefix() != null || inIndexsee) {
                        indexSeeRefTerm = term.getTermName();
                        inIndexsee = true;
                        foundIndexsee = true;
                        // Find the term with an href.
                        for (int j = 0; j < termCloneNum; j++) {
                            final IndexTerm termClone = termCloneList.get(j);
                            if (term.getTermName().equals(termClone.getTermName())) {
                                foundIndexTerm = true;
                                if (termClone.getTargetList().size() > 0) {
                                    serializer.writeStartElement("topic");
                                    final IndexTermTarget indexTermTarget = termClone.getTargetList().get(0);
                                    serializer.writeAttribute("href", replaceExtName(indexTermTarget.getTargetURI()));
                                    if (indexTermTarget.getTargetName() != null && !indexTermTarget.getTargetName().trim().isEmpty()) {
                                        serializer.writeAttribute("title", indexTermTarget.getTargetName());
                                    }
                                    serializer.writeEndElement(); // topic
                                }
                                /*
                                 * We found the term we are looking for, but it
                                 * does not have a target name (title). We need
                                 * to take a look at the subterms for the
                                 * redirect and
                                 */
                                termCloneList = termClone.getSubTerms();
                                break;
                            }
                        }// end for
                        // If there are no subterms, then we are done.
                        if (term.getSubTerms().size() == 0) {
                            inIndexsee = false;
                        }
                    } else {
                        serializer.writeStartElement("topic");
                        serializer.writeAttribute("href", replaceExtName(targetUri));
                        if (targetName.trim().length() > 0) {
                            serializer.writeAttribute("title", target.getTargetName());
                        }
                        serializer.writeEndElement(); // topic
                    }
                }
            }//end for
            if (!foundIndexTerm && foundIndexsee && indexSeeRefTerm != null && !indexSeeRefTerm.equals("***")){
                logger.warn(MessageUtils.getMessage("DOTJ050W", indexSeeRefTerm.trim()).toString());
            }
        }

    }

    /*
     * Specific method for new markup for see references in Eclipse. Depends on
     * Eclipse 3.6.
     * 
     * @param term The indexterm to be processed.
     * @param printWriter The Writer used for writing content to disk.
     */

    private void outputIndexEntryEclipseIndexsee(final IndexTerm term,
            final XMLStreamWriter serializer) throws XMLStreamException {
        final List<IndexTermTarget> targets = term.getTargetList();

        // Index-see and index-see-also terms should also generate links to its
        // target
        // Otherwise, the term won't be displayed in the index tab.
        if (!targets.isEmpty()) {
            for (final IndexTermTarget target : targets) {
                final String targetUri = target.getTargetURI();
                final String targetName = target.getTargetName();
                if (targetUri == null) {
                    serializer.writeStartElement("topic");
                    serializer.writeAttribute("title", target.getTargetName());
                    serializer.writeEndElement(); // topic
                } else {
                    serializer.writeStartElement("topic");
                    serializer.writeAttribute("href", replaceExtName(targetUri));

                    if (targetName.trim().length() > 0) {
                        serializer.writeAttribute("title", target.getTargetName());
                    }
                    serializer.writeEndElement(); // topic
                }
            }
        }// end for
    }

    /*
     * Clone a list used for comparison against the original list.
     * 
     * @param  List A list to be deep cloned
     * @return List The deep cloned list
     */

    private List<IndexTerm> cloneIndextermList (final List<IndexTerm> termList){
        final List<IndexTerm> termListClone = new ArrayList<>(termList.size());
        if (!termList.isEmpty()){
            termListClone.addAll(termList);
        }
        return termListClone;
    }

    /*
     * Logic for adding various start index entry elements for Eclipse help.
     * 
     * @param term  The indexterm to be processed.
     * @param printWriter The Writer used for writing content to disk.
     * @param indexsee Boolean value for using the new markup for see references.
     */
    private void outputIndexTermStartElement(final IndexTerm term, final XMLStreamWriter serializer, final boolean indexsee) throws XMLStreamException {
        //RFE 2987769 Eclipse index-see
        if (indexsee){
            if (term.getTermPrefix() != null) {
                inIndexsee = true;
                serializer.writeStartElement("see");
                serializer.writeAttribute("keyword", term.getTermName());
            } else if (inIndexsee) { // subterm of an indexsee.
                serializer.writeStartElement("subpath");
                serializer.writeAttribute("keyword", term.getTermName());
                serializer.writeEndElement(); // subpath
            } else {
                serializer.writeStartElement("entry");
                serializer.writeAttribute("keyword", term.getTermName());
                outputIndexEntryEclipseIndexsee(term, serializer);
            }
        } else {
            serializer.writeStartElement("entry");
            serializer.writeAttribute("keyword", term.getTermFullName());
            outputIndexEntry(term, serializer);
        }
    }

    /*
     * Logic for adding various end index entry elements for Eclipse help.
     * 
     * @param term  The indexterm to be processed.
     * @param printWriter The Writer used for writing content to disk.
     * @param indexsee Boolean value for using the new markup for see references.
     */
    private void outputIndexTermEndElement(final IndexTerm term, final XMLStreamWriter serializer, final boolean indexsee) throws XMLStreamException {
        if (indexsee){
            if (term.getTermPrefix() != null) {
                serializer.writeEndElement(); // see
                inIndexsee = false;
            } else if (inIndexsee) {
                // NOOP
            } else {
                serializer.writeEndElement(); // entry
            }
        } else {
            serializer.writeEndElement(); // entry
        }
    }

}
