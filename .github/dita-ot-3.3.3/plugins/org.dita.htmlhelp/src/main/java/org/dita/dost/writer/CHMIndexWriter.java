/*
 * This file is part of the DITA Open Toolkit project.
 *
 * Copyright 2005 IBM Corporation
 *
 * See the accompanying LICENSE file for applicable license.

 */
package org.dita.dost.writer;

import java.io.File;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.OutputStream;
import java.util.List;

import javax.xml.transform.Transformer;

import org.xml.sax.SAXException;
import org.dita.dost.exception.DITAOTException;
import org.dita.dost.index.IndexTerm;
import org.dita.dost.index.IndexTermTarget;
import org.dita.dost.util.XMLSerializer;

/**
 * This class extends AbstractWriter, used to output IndexTerm list to CHM index
 * file.
 * 
 * @version 1.0 2005-05-11
 * 
 * @author Wu, Zhi Qiang
 */
public final class CHMIndexWriter extends AbstractExtendDitaWriter {

    @Override
    public void write(final File filename) throws DITAOTException {
        OutputStream out = null;
        try {
            out = new FileOutputStream(filename);
            final XMLSerializer serializer = XMLSerializer.newInstance(out);
            final Transformer transformer = serializer.getTransformerHandler().getTransformer();
            transformer.setOutputProperty("doctype-public", "-//IETF//DTD HTML//EN");
            transformer.setOutputProperty("method", "html");
            transformer.setOutputProperty("encoding", "UTF-8");
            transformer.setOutputProperty(javax.xml.transform.OutputKeys.INDENT, "no");


            serializer.writeStartDocument();
            serializer.writeStartElement("html");
            serializer.writeStartElement("head");
            serializer.writeStartElement("meta");
            serializer.writeAttribute("name", "GENERATOR");
            serializer.writeAttribute("content", "Microsoft\u00AE HTML Help Workshop 4.1");
            serializer.writeEndElement(); // meta
            serializer.writeComment("Sitemap 1.0");
            serializer.writeEndElement(); // head
            serializer.writeStartElement("body");
            serializer.writeStartElement("ul");
            for (final IndexTerm term : termList) {
                outputIndexTerm(term, serializer);
            }
            serializer.writeEndElement(); // ul
            serializer.writeEndElement(); // body
            serializer.writeEndElement(); // html
            serializer.writeEndDocument();
        } catch (final RuntimeException e) {
            throw e;
        } catch (final Exception e) {
            throw new DITAOTException(e);
        } finally {
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
     */
    private void outputIndexTerm(final IndexTerm term, final XMLSerializer serializer) throws SAXException {
        List<IndexTermTarget> targets = term.getTargetList();
        final List<IndexTerm> subTerms = term.getSubTerms();
        int targetNum = targets.size();
        final int subTermNum = subTerms.size();

        serializer.writeStartElement("li");
        serializer.writeStartElement("object");
        serializer.writeAttribute("type", "text/sitemap");
        serializer.writeStartElement("param");
        serializer.writeAttribute("name", "Name");
        serializer.writeAttribute("value", term.getTermFullName());
        serializer.writeEndElement(); // param
        //if term doesn't has target to link to, it won't appear in the index tab
        //we need to create links for such terms
        if (targets.isEmpty()){
            findTargets(term);
            targets = term.getTargetList();
            targetNum = targets.size();
        }
        for (int i = 0; i < targetNum; i++) {
            final IndexTermTarget target = targets.get(i);
            serializer.writeStartElement("param");
            serializer.writeAttribute("name", "Name");
            serializer.writeAttribute("value", target.getTargetName());
            serializer.writeEndElement(); // param
            serializer.writeStartElement("param");
            serializer.writeAttribute("name", "Local");
            serializer.writeAttribute("value", target.getTargetURI());
            serializer.writeEndElement(); // param
        }
        serializer.writeEndElement(); // object
        if (subTermNum > 0) {
            serializer.writeStartElement("ul");
            for (final IndexTerm subTerm : subTerms) {
                outputIndexTerm(subTerm, serializer);
            }
            serializer.writeEndElement(); // ul
        }
        serializer.writeEndElement(); // li
    }

    /**
     * find the targets in its subterms when the current term doesn't have any target
     * 
     * @param term The current IndexTerm instance
     */
    private void findTargets(final IndexTerm term) {
        final List<IndexTerm> subTerms = term.getSubTerms();
        List<IndexTermTarget> subTargets = null;
        if (subTerms != null && ! subTerms.isEmpty()){
            for (final IndexTerm subTerm : subTerms) {
                subTargets = subTerm.getTargetList();
                if (subTargets != null && !subTargets.isEmpty()) {
                    //findTargets(subTerm);
                    //add targets(child term)
                    term.addTargets(subTerm.getTargetList());
                } else {
                    //term.addTargets(subTerm.getTargetList());
                    //recursive search child's child term
                    findTargets(subTerm);
                }
                //add target to parent indexterm
                term.addTargets(subTerm.getTargetList());
            }

        }
    }

    /**
     * Get index file name.
     * @param outputFileRoot root
     * @return index file name
     */
    @Override
    public String getIndexFileName(final String outputFileRoot) {
        return outputFileRoot + ".hhk";
    }

}
